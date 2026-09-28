import Phaser from 'phaser';
import { battlefieldPlan, type Battlefield } from './battlefield';
import { requireImage } from '../content/schema';
import type { Insets } from './projection';
import { hudCanvas, type HudCanvas } from '../hud/layout';
import { mountHud, hudImageKeys } from '../hud/view';
import type { HudContent } from '../hud/state';
import type { Row } from '../data/records';
import type { BattleStore } from './store';
import { actorPlan, destination } from './actors';
import { contains } from '../hud/layout';
import { projectilePlan, impactPlan, moralePlan } from './combat-view';
import { dt } from './schedules';
import { towerCursor, mountTowerUI, type TowerCursors } from '../hud/tower-view';
import { towerSprite } from '../hud/tower-layout';
import { chargeSymbol, fieldArtwork, obstacleField } from './tower-effects';
import { hudSizing } from '../hud/layout';
import type { Presentation } from '../content/presentation';
import { ImageUpdates } from './image-updates';
import { ActorMarks } from './actor-marks';
import { ImagePool } from './image-pool';

export interface Renderer { ready: Promise<void>; destroy(): void }
export type HudBattlefield = Battlefield & { canvas: Row<'virtual_canvas'>; hud: HudContent; presentation:Presentation; store?: BattleStore };
export type Render = (host: HTMLElement, battle: HudBattlefield, progress: (fraction: number) => void) => Renderer;

// CSS env() values are the browser equivalent of UIWindow safe-area insets.
// An unset property means the host has no platform inset (e.g. an embedded host).
function safeInsets(host: HTMLElement): Insets {
  const style = getComputedStyle(host);
  const edge = (name: string) => Number.parseFloat(style.getPropertyValue(`--safe-${name}`) || '0');
  return { top: edge('top'), right: edge('right'), bottom: edge('bottom'), left: edge('left') };
}

export const render: Render = (host, battle, progress) => {
  let resolve!: () => void;
  let reject!: (reason: unknown) => void;
  let failed = false;
  const ready = new Promise<void>((yes, no) => { resolve = yes; reject = no; });
  let hud: ReturnType<typeof mountHud> | undefined;
  let towerUI: ReturnType<typeof mountTowerUI> | undefined;
  const store = battle.store, session = store?.session;
  let detachPointer = () => {};
  let unsubscribe = () => {};
  let detachScene = () => {};
  class BattlefieldScene extends Phaser.Scene {
    private readonly images = new ImageUpdates();
    private readonly battlefieldImages = new Map<number, Phaser.GameObjects.Image>();
    private actors = new Map<string, { image: Phaser.GameObjects.Image; marks: ActorMarks }>();
    private effects: ImagePool | undefined;
    private groundState: unknown[] = [];
    private smokeState: unknown[] = [];
    private towerImages = new Map<number, Phaser.GameObjects.Image>();
    private fields = new Map<number,{stamp:string;key:string;image:Phaser.GameObjects.Image}>();
    private ground:Phaser.GameObjects.Graphics|undefined;
    private rally:Phaser.GameObjects.Image|undefined;
    private shots = new Map<number, Phaser.GameObjects.Image>();
    private bursts = new Map<string, Phaser.GameObjects.Image>();
    private smoke: Phaser.GameObjects.Graphics | undefined;
    private reduceMotion = host.ownerDocument.defaultView?.matchMedia?.('(prefers-reduced-motion: reduce)').matches === true;
    private occupied = '';
    private readout: HTMLElement | undefined;
    private viewport: HudCanvas | undefined;
    private advancing = false;
    view() { return this.viewport ??= hudCanvas(battle.canvas, this.scale.width, this.scale.height, battle.presentation.towerGeometry, safeInsets(host)); }
    preload() {
      try {
        const keys = new Set([...this.plan().map(p => p.key), ...hudImageKeys(battle.hud.state), ...session?.imageKeys ?? []]);
        for (const key of keys) this.load.image(key, requireImage(battle.manifest, key).url);
        this.load.on('progress', progress);
        this.load.on('loaderror', (file: { key: string }) => {
          failed = true;
          reject(new Error(`Required art failed to load: ${file.key}`));
        });
      } catch (error) { failed = true; reject(error); }
    }
    create() {
      if (failed) return;
      try {
        hud = mountHud(host, battle.manifest, battle.hud, store?.hudInput);
        if (session) {
          this.effects=new ImagePool(this);
          const g=session.presentation.towerGeometry;
          for(const profile of Object.values(session.presentation.towers)) for(const sprite of Object.values(profile.tiers)) if(sprite.atlas){
            const texture=this.textures.get(sprite.atlas),asset=requireImage(battle.manifest,sprite.atlas);
            const w=asset.width/g.atlasColumns,h=asset.height/g.atlasRows;
            if(!Number.isInteger(w)||!Number.isInteger(h))throw Error(`Invalid tower atlas dimensions: ${sprite.atlas}`);
            for(let i=0;i<g.atlasColumns*g.atlasRows;i++)texture.add(String(i),0,(i%g.atlasColumns)*w,Math.floor(i/g.atlasColumns)*h,w,h);
          }
          const explosion=session.presentation.explosion,texture=this.textures.get(explosion.asset),asset=requireImage(battle.manifest,explosion.asset);
          const ew=asset.width/explosion.columns,eh=asset.height/explosion.rows;
          if(!Number.isInteger(ew)||!Number.isInteger(eh))throw Error(`Invalid explosion atlas dimensions: ${explosion.asset}`);
          for(let i=0;i<explosion.frameEnds.length;i++)texture.add(String(i),0,i%explosion.columns*ew,Math.floor(i/explosion.columns)*eh,ew,eh);
          const cursor=(key:string,kind:keyof TowerCursors)=>{
            const asset=requireImage(battle.manifest,key),source=this.textures.get(key).getSourceImage();
            if (!(source instanceof HTMLImageElement || source instanceof HTMLCanvasElement)) throw Error(`Invalid ${kind} cursor texture`);
            return towerCursor(host.ownerDocument,source,asset.width,asset.height,kind);
          };
          towerUI=mountTowerUI(host,battle.manifest,store!,{
            build:cursor('tower_slot_build_flag','build'),upgrade:cursor('tower_slot_upgrade','upgrade'),
          });
        }
        session?.clock.resync();
        this.draw();
        if (session) {
          this.readout = host.ownerDocument.createElement('output'); this.readout.className = 'simulation-readout'; host.append(this.readout);
          let down: { id: number; x: number; y: number } | undefined;
          const start = (event: PointerEvent) => {
            down = event.button === 0 && (event.target as HTMLElement).tagName === 'CANVAS'
              ? { id: event.pointerId, x: event.clientX, y: event.clientY } : undefined;
          };
          const end = (event: PointerEvent) => {
            const from = down; down = undefined;
            if (!from || (event.target as HTMLElement).tagName !== 'CANVAS' || from.id !== event.pointerId || Math.hypot(from.x - event.clientX, from.y - event.clientY) > 10 || !session.acceptsInput) return;
            const bounds = host.getBoundingClientRect(), view = this.view();
            const point = { x: (event.clientX - bounds.x) * this.scale.width / bounds.width, y: (event.clientY - bounds.y) * this.scale.height / bounds.height };
            if (session.selectedHero !== null || session.placing || session.towers.selected !== null) { const target = destination(view, point); if (target) store!.dispatch({ type: 'mapTap', point: target }); }
            else {
              const hero = session.actors().filter(a => a.kind === 'hero').reverse()
                .map(a => actorPlan(a, view, battle.manifest, session.presentation)).find(a => contains(a.tapRect, point));
              if (hero) store!.dispatch({ type: 'selectHero', index: hero.heroIndex! });
            }
          };
          const cancel = () => { down = undefined; };
          host.addEventListener('pointerdown', start); host.addEventListener('pointerup', end); host.addEventListener('pointercancel', cancel); host.addEventListener('pointerleave', cancel);
          detachPointer = () => { host.removeEventListener('pointerdown', start); host.removeEventListener('pointerup', end); host.removeEventListener('pointercancel', cancel); host.removeEventListener('pointerleave', cancel); this.readout?.remove(); };
          const changed = () => this.syncState();
          this.events.on('battle-state-changed', changed);
          unsubscribe = store!.subscribe(() => this.events.emit('battle-state-changed'));
          detachScene = () => { unsubscribe(); this.events.off('battle-state-changed', changed); detachPointer(); };
          session.clock.resync(); this.syncState();
        }
        const resize = () => { this.viewport = undefined; this.draw(); this.syncState(); };
        this.scale.on('resize', resize);
        this.events.once('shutdown', () => { this.scale.off('resize', resize); detachScene(); });
        resolve();
      } catch (error) { reject(error); }
    }
    plan() {
      return battlefieldPlan(battle, this.scale.width, this.scale.height, safeInsets(host),new Set(session?.towers.placed.map(t=>t.slot)));
    }
    draw() {
      this.drawBattlefield();
      hud?.draw(this.view());
      this.renderFrame();
    }
    private drawBattlefield() {
      const plan=this.plan();
      plan.forEach((p,index)=>{
        if(!this.battlefieldImages.has(index))this.battlefieldImages.set(index,this.add.image(p.x,p.y,p.key));
        this.images.apply(this.battlefieldImages.get(index)!,{...p,originX:p.origin,originY:p.origin});
      });
      for(const [index,image] of this.battlefieldImages)if(index>=plan.length){image.destroy();this.battlefieldImages.delete(index);}
    }
    update() {
      this.advancing = true;
      try { store?.frame(); } finally { this.advancing = false; }
      this.renderFrame();
    }
    private syncState() {
      if (!session || !hud) return;
      hud.update(session.hud, session.player);
      const debug=Boolean(session.player.settings.debug_mode);
      if(host.classList.contains('debug-mode')!==debug)host.classList.toggle('debug-mode',debug);
      const cursor=session.acceptsInput && (session.placing || session.selectedHero !== null || session.towers.placement !== null) ? 'crosshair' : '';
      if(host.style.cursor!==cursor)host.style.cursor=cursor;
      towerUI?.sync(this.view());
      if(!this.advancing)towerUI?.frame(this.view());
    }
    private renderFrame() {
      if (!session || !hud) return;
      const occupied=session.towers.placed.map(t=>t.slot).join(',');
      if(occupied!==this.occupied){this.occupied=occupied;this.drawBattlefield();}
      const view = this.view();
      const occupiedSlots=new Set(session.towers.placed.map(t=>t.slot));
      for(const [slot,image] of this.towerImages)if(!occupiedSlots.has(slot)){image.destroy();this.towerImages.delete(slot);}
      for(const [slot,field] of this.fields)if(!occupiedSlots.has(slot)){field.image.destroy();this.textures.remove(field.key);this.fields.delete(slot);}
      for(const tower of session.towers.placed){
        const tuning=session.towers.tuning(tower),seconds=session.clock.tick*dt;
        const p=towerSprite(tower,tuning,view,battle.manifest,session.presentation,session.combat.heading(tower),seconds);
        if(!this.towerImages.has(tower.slot))this.towerImages.set(tower.slot,this.add.image(0,0,p.key,p.frame));
        this.images.apply(this.towerImages.get(tower.slot)!, {key:p.key,frame:p.frame,...p.rect,originX:0,originY:0,depth:10.5});
        const field=tower.site===null?null:obstacleField(tower.site,tuning,session.content.routes),stamp=JSON.stringify(field),previous=this.fields.get(tower.slot);
        if(previous&&previous.stamp!==stamp){previous.image.destroy();this.textures.remove(previous.key);this.fields.delete(tower.slot);}
        if(field&&!this.fields.has(tower.slot)){
          const asset=requireImage(battle.manifest,'engineer_rough_ground'),source=this.textures.get('engineer_rough_ground').getSourceImage();
          if(!(source instanceof HTMLImageElement||source instanceof HTMLCanvasElement))throw Error('Invalid engineer texture');
          const key=`engineer-field-${tower.slot}`,canvas=fieldArtwork(host.ownerDocument,source,asset.width,field,session.content.area.rings);
          this.textures.addCanvas(key,canvas);
          const image=this.add.image(0,0,key);
          this.fields.set(tower.slot,{stamp,key,image});
        }
        const rendered=this.fields.get(tower.slot);
        if(field&&rendered){const at=view.point(field.position.x,field.position.y);
          this.images.apply(rendered.image,{key:rendered.key,...at,width:field.radius*2*view.scale,height:field.radius*2*field.widthFraction*view.scale,
            originX:.5,originY:.5,rotation:-field.heading,depth:10.1});}
      }
      if(!this.ground)this.ground=this.add.graphics().setDepth(10.4);
      const charged=session.towers.placed.filter(t=>t.charge!==null||t.chargeRemaining>0);
      const groundState=[view,session.towers.selected,charged.length?session.clock.tick:0,
        ...charged.flatMap(t=>[t.slot,t.position.x,t.position.y,t.charge?.x,t.charge?.y,t.chargeRemaining,session.towers.tuning(t)])];
      if(!sameInputs(this.groundState,groundState)){
      this.groundState=groundState;this.ground.clear().setVisible(charged.length>0);
      for(const tower of charged){
        const tuning=session.towers.tuning(tower);
        if(tower.charge!==null){
          const at=view.point(tower.charge.x,tower.charge.y);
          if(session.towers.selected===tower.slot){const radius=tuning.aoe_radius*view.scale;
            this.ground.fillStyle(0xff9500,.12).fillCircle(at.x,at.y,radius).lineStyle(2,0xff9500).strokeCircle(at.x,at.y,radius);}
          if(tower.chargeRemaining===0)for(const shape of chargeSymbol(at,session.clock.tick*dt)){
            this.ground.fillStyle(shape.color,shape.alpha);
            if(shape.kind==='circle')this.ground.fillCircle(shape.x,shape.y,shape.width/2);
            else if(shape.kind==='ellipse')this.ground.fillEllipse(shape.x,shape.y,shape.width,shape.height);
            else this.ground.fillRoundedRect(shape.x,shape.y,shape.width,shape.height,shape.round);
          }
        }
        if(tower.chargeRemaining>0){const p=towerSprite(tower,tuning,view,battle.manifest,session.presentation,session.combat.heading(tower),0);
          const x=p.rect.x+p.rect.width/2,y=p.rect.y+p.rect.height+8,progress=1-tower.chargeRemaining/tuning.demolition_prepare_seconds!;
          this.ground.fillStyle(0x000000).fillRoundedRect(x-15,y-3,30,6,3).fillStyle(0x26e64d).fillRoundedRect(x-14,y-2,28*progress,4,2);}
      }
      }
      if(session.towers.flash){
        if(!this.rally)this.rally=this.add.image(0,0,'rally_point_icon').setDepth(21);
        const size=Math.min(Math.max(81.29*view.playArea.height/hudSizing.referencePlayableHeight,44),81.29*1.2)*.45;
        const point=view.point(session.towers.flash.x,session.towers.flash.y),asset=requireImage(battle.manifest,'rally_point_icon'),scale=size/Math.max(asset.width,asset.height);
        this.rally.setPosition(point.x,point.y+size*(.5-.69)).setDisplaySize(asset.width*scale,asset.height*scale).setAlpha(Math.min(1,session.towers.flashRemaining));
      }else if(this.rally){this.rally.destroy();this.rally=undefined;}
      const liveShots=new Set(session.combat.projectiles.map(p=>p.id));
      for(const [id,image] of this.shots)if(!liveShots.has(id)){this.effects!.release(image);this.shots.delete(id);}
      for(const projectile of session.combat.projectiles){
        const p=projectilePlan(projectile,session.paused||session.outcome?1:session.clock.alpha,view,battle.manifest,session.presentation);
        if(!this.shots.has(projectile.id))this.shots.set(projectile.id,this.effects!.acquire(p.key));
        this.images.apply(this.shots.get(projectile.id)!, {...p,originX:.5,originY:.5,depth:21});
      }
      if(!this.smoke)this.smoke=this.add.graphics().setDepth(10.8);
      const smokeState=[view,...session.combat.impacts.flatMap(i=>[i.id,i.position.x,i.position.y,i.radius,i.age,i.demolition])];
      const redrawSmoke=!sameInputs(this.smokeState,smokeState);
      if(redrawSmoke){this.smokeState=smokeState;this.smoke.clear().setVisible(session.combat.impacts.length>0);}
      const liveBursts=new Set<string>();
      for(const impact of session.combat.impacts){
        const p=impactPlan(impact,view,session.presentation,this.reduceMotion);
        if(redrawSmoke)for(const shape of p.shapes){
          if(shape.stroke)this.smoke.lineStyle(shape.stroke,shape.color,shape.alpha).strokeEllipse(shape.x,shape.y,shape.width,shape.height);
          else this.smoke.fillStyle(shape.color,shape.alpha).fillEllipse(shape.x,shape.y,shape.width,shape.height);
        }
        for(const frame of p.frames){const id=`${impact.id}:${frame.frame}`;liveBursts.add(id);
          if(!this.bursts.has(id))this.bursts.set(id,this.effects!.acquire(p.key,frame.frame));
          const art=requireImage(battle.manifest,p.key),w=art.width/session.presentation.explosion.columns,h=art.height/session.presentation.explosion.rows,scale=p.side/Math.max(w,h);
          this.images.apply(this.bursts.get(id)!, {key:p.key,frame:frame.frame,x:p.x,y:p.y,width:w*scale,height:h*scale,
            originX:.5,originY:.5,alpha:frame.alpha,depth:10.9});
        }
      }
      for(const [id,image] of this.bursts)if(!liveBursts.has(id)){this.effects!.release(image);this.bursts.delete(id);}
      const actors = session.actors(), live = new Set(actors.map(a => a.id));
      for (const [id, object] of this.actors) if (!live.has(id)) { object.image.destroy(); object.marks.graphics.destroy(); this.actors.delete(id); }
      for (const actor of actors) {
        const p = actorPlan(actor, view, battle.manifest, session.presentation);
        if (!this.actors.has(actor.id)) this.actors.set(actor.id, { image: this.add.image(0, 0, actor.key), marks: new ActorMarks(this.add.graphics()) });
        const { image, marks } = this.actors.get(actor.id)!;
        const morale=actor.morale?moralePlan(actor.morale,{x:0,y:0},p.frame.height,session.presentation,this.reduceMotion):null;
        this.images.apply(image,{key:actor.key,originX:.5,originY:1,x:p.foot.x+(morale?.dx??0),y:p.frame.y+p.frame.height+(morale?.dy??0),
          width:p.frame.width,height:p.frame.height,rotation:morale?.rotation??0,depth:p.depth});
        marks.update(p,morale,session.presentation.healthHeight.minimum);
      }
      if (this.readout) {
        const hidden=!session.player.settings.show_debug_info;
        if(this.readout.hidden!==hidden)this.readout.hidden=hidden;
        if(!hidden){const text=`${(session.clock.tick * dt).toFixed(1)}s · ${session.clock.factor}× · ${session.enemies.length} enemies`;
          if(this.readout.textContent!==text)this.readout.textContent=text;}
      }
      towerUI?.frame(view, actors);
    }
  }
  const game = new Phaser.Game({
    type: Phaser.AUTO, parent: host, backgroundColor: '#182822',
    scale: { mode: Phaser.Scale.RESIZE, width: host.clientWidth, height: host.clientHeight },
    render: { antialias: true }, scene: [BattlefieldScene],
    audio: { noAudio: true }, // No audio ported in this milestone.
  });
  return { ready, destroy: () => { detachScene(); hud?.destroy(); towerUI?.destroy(); host.style.cursor = ''; host.classList.remove('debug-mode'); game.destroy(true); } };
};

function sameInputs(previous: unknown[], next: unknown[]) {
  return previous.length===next.length&&previous.every((value,i)=>value===next[i]);
}
