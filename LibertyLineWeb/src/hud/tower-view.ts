import { requireImage, type Manifest } from '../content/schema';
import type { BattleStore } from '../game/store';
import type { Actor } from '../game/session';
import { actorPlan } from '../game/actors';
import type { TowerKind } from '../game/tower-tuning';
import { labelPlacement, slotTarget, towerMenuPlan } from './tower-layout';
import { place } from './view';
import { waveLayout, type HudCanvas, type Rect } from './layout';

const svgNamespace = 'http://www.w3.org/2000/svg';
export type TowerCursors = { build: string; upgrade: string };
export function towerCursor(document: Document, image: CanvasImageSource, width: number, height: number, kind: keyof TowerCursors) {
  const size = Math.round(32 * 1.33);
  const canvas = document.createElement('canvas'); canvas.width = canvas.height = size;
  const context = canvas.getContext('2d'); if (!context) throw Error(`Unable to create ${kind} cursor`);
  const scale = size / Math.max(width,height); context.drawImage(image,0,0,width*scale,height*scale);
  // Click at the hammer's iron head or just inside the upward arrow's tip.
  const point = kind === 'build' ? { x: 5/32, y: 12/32 } : { x: .5, y: .1 };
  return `url("${canvas.toDataURL('image/png')}") ${Math.round(point.x*size)} ${Math.round(point.y*size)}, pointer`;
}
export function mountTowerUI(host: HTMLElement, art: Manifest, store: BattleStore, cursors: TowerCursors) {
  const document = host.ownerDocument, session = store.session;
  const targets = document.createElement('div'), root = document.createElement('div');
  targets.className = 'world-controls'; root.className = 'tower-menu'; root.setAttribute('aria-label','Tower menu');
  host.append(targets,root);
  let view: HudCanvas, last = '', slotsStamp = '', geometry = '';
  const targetButtons = new Map<string, HTMLButtonElement>();
  const choices = new Map<string, HTMLButtonElement>();
  const target = (key: string, label: string, rect: Rect, handler: () => void, ellipse: boolean, enabled: boolean, style: string) => {
    let button = targetButtons.get(key);
    if (!button) { button = document.createElement('button'); button.type='button'; button.className='world-target'; button.dataset.target=key;
      button.onclick=handler; button.style.borderRadius=ellipse?'50%':'0'; button.style.clipPath=ellipse?'ellipse(50% 50%)':'';
      // Hero targets retain precedence even when static slots are added later.
      button.style.zIndex=ellipse?'0':'1';
      targets.append(button); targetButtons.set(key,button); }
    if(button.getAttribute('aria-label')!==label)button.setAttribute('aria-label',label);
    if(button.disabled===enabled)button.disabled=!enabled;
    const pointer=enabled?'auto':'none';
    if(button.style.pointerEvents!==pointer)button.style.pointerEvents=pointer;
    if(button.style.cursor!==style)button.style.cursor=style;
    place(button,rect);
  };
  const image = (parent: HTMLElement, key: string, rect: Rect, crop = false) => {
    const asset=requireImage(art,key);
    const box=document.createElementNS(svgNamespace,'svg'); box.classList.add('tower-art'); box.setAttribute('aria-hidden','true');
    const bounds=crop?asset.bounds:{x:0,y:0,width:asset.width,height:asset.height};
    if (!bounds) throw Error(`images[${key}].bounds: missing canonical alpha bounds`);
    box.setAttribute('viewBox',`${bounds.x} ${bounds.y} ${bounds.width} ${bounds.height}`);
    const pixels=document.createElementNS(svgNamespace,'image'); pixels.setAttribute('href',asset.url);
    pixels.setAttribute('width',String(asset.width)); pixels.setAttribute('height',String(asset.height));
    box.append(pixels); place(box,rect); parent.append(box); return box;
  };
  const active = () => session.acceptsInput && session.selectedHero===null && !session.placing && session.towers.selected===null;
  function frame(next: HudCanvas, actors: Actor[] = session.actors(undefined, true)) {
    const alive=new Set<string>();
    for (const actor of actors) if(actor.kind==='hero') {
      const plan=actorPlan(actor,next,art,session.presentation), key=actor.id; alive.add(key);
      target(key,`Select ${session.heroes[actor.heroIndex!]!.hero!.short_name}`,plan.tapRect,()=>store.dispatch({type:'selectHero',index:actor.heroIndex!}),false,active(),'pointer');
    }
    for (const [key,node] of targetButtons) if(!key.startsWith('slot:')&&!alive.has(key)){node.remove();targetButtons.delete(key);}
  }
  function sync(next: HudCanvas) {
    const nextGeometry=view===next?geometry:JSON.stringify([next.scale,next.safeRect,next.physicalRect,next.playArea,next.corners,next.canvas.slot_width,next.canvas.slot_height]);
    const resized=geometry!==nextGeometry;geometry=nextGeometry;
    view=next;
    const towers=session.towers, enabled=active(), occupiedSlots=new Set(towers.placed.map(t=>t.slot));
    const slotState=JSON.stringify([enabled,[...occupiedSlots],session.content.slots]);
    if(resized||slotState!==slotsStamp){
    slotsStamp=slotState;
    const alive=new Set<string>();
    for (const slot of session.content.slots) {
      const occupied=occupiedSlots.has(slot.index), key=`slot:${slot.index}`; alive.add(key);
      target(key,`${occupied?'Select tower':'Build tower'}, slot ${slot.index+1}`,slotTarget(slot,view,session.presentation,{width:view.canvas.slot_width,height:view.canvas.slot_height}),
        ()=>store.dispatch({type:'selectTower',slot:slot.index}),true,enabled,occupied?cursors.upgrade:cursors.build);
    }
    for (const [key,node] of targetButtons) if(key.startsWith('slot:')&&!alive.has(key)){node.remove();targetButtons.delete(key);}
    }
    // Select inexpensive state before computing menu geometry/descriptions.
    const stamp=towers.selected===null?'closed':JSON.stringify([towers.selected,towers.armed,towers.placement,towers.money,
      towers.meta.selectionKey,towers.placed.map(t=>[t.slot,t.kind,t.level,t.branch,t.ranks,t.position,t.rally!==null]),
      session.content.unlocks,session.hud.callWavePositions,session.acceptsInput]);
    if(!resized&&stamp===last)return; last=stamp;
    const plan=towerMenuPlan(towers,view,session.presentation), range=towers.range;
    // Keep interactive nodes attached across state changes during a press.
    // Artwork and labels are pointer-transparent or independent scroll controls.
    for (const child of Array.from(root.children)) if (!child.classList.contains('tower-choice')) child.remove();
    const liveChoices = new Set(plan?.buttons.map(b => b.id));
    for (const [id, button] of choices) if (!liveChoices.has(id)) { button.remove(); choices.delete(id); }
    if(range) {
      const svg=document.createElementNS(svgNamespace,'svg'); svg.classList.add('tower-ranges');
      svg.setAttribute('width',String(view.physicalRect.width)); svg.setAttribute('height',String(view.physicalRect.height)); root.append(svg);
      const p=view.point(range.center.x,range.center.y);
      for(const [i,radius] of [range.upgrade,range.radius].entries()) if(radius!==null){
        const rx=radius*view.scale, ry=rx*session.content.config.combat.range_vertical_fraction;
        const fade=Math.min(.1,6/Math.max(ry,1)), opacity=i===0?.4:.7, gradient=document.createElementNS(svgNamespace,'radialGradient');
        const id=`tower-range-${i}`; gradient.id=id;
        for(const [offset,alpha] of [[0,0],[1-fade,0],[1-fade/2,opacity*.35],[1,opacity]]){
          const stop=document.createElementNS(svgNamespace,'stop'); stop.setAttribute('offset',String(offset));stop.setAttribute('stop-color','#5842c7');stop.setAttribute('stop-opacity',String(alpha));gradient.append(stop);
        }
        svg.append(gradient); const ellipse=document.createElementNS(svgNamespace,'ellipse');
        for(const [key,value] of Object.entries({cx:p.x,cy:p.y,rx,ry,fill:`url(#${id})`,stroke:'#5842c7','stroke-width':2,'stroke-dasharray':i===0?'6 4':'none'}))ellipse.setAttribute(key,String(value));
        svg.append(ellipse);
      }
    }
    if(!plan)return;
    image(root,'tower_menu_bg',plan.background).setAttribute('preserveAspectRatio','none');
    for(const item of plan.buttons){
      let button=choices.get(item.id);
      if (!button) { button=document.createElement('button');button.type='button';button.className='tower-choice';button.dataset.choice=item.id;choices.set(item.id,button);root.append(button); }
      button.replaceChildren();
      button.setAttribute('aria-label',item.label);button.setAttribute('aria-pressed',String(towers.armed===item.id));
      button.setAttribute('aria-description',item.id==='placement'?'Choose a location':item.disabled?'Locked or fully upgraded':item.cost===null?'Fully upgraded':`${item.armed?'Confirm. ':''}${item.cost} coins${item.affordable?'':'. Not enough money'}`);
      button.disabled=item.disabled || !session.acceptsInput;place(button,item.frame);
      const side=item.frame.width, local={x:0,y:0,width:side,height:side};
      if(item.armed){
        image(button,'tower_build_confirm',local);
        if(!item.affordable){const shade=image(button,'tower_build_confirm',local);shade.style.filter='grayscale(1)';shade.style.clipPath='inset(8.7% round 4.5%)';}
      }else{
        image(button,item.art,local);
        const margin=side*plan.iconInset;
        const icon=image(button,item.icon,{x:margin,y:margin,width:side-2*margin,height:side-2*margin},true);
        if(item.cost!==null&&!item.affordable)icon.style.filter='grayscale(1)';
        if(item.id==='max')icon.style.opacity='.5';
        if(item.id!=='placement' && (!item.disabled || item.id==='max')){
          const cost=document.createElement('span');cost.className='tower-price';cost.textContent=item.cost===null?'MAX':String(item.cost);
          Object.assign(cost.style,{left:`${side/2}px`,top:`${side*.9568}px`,fontSize:`${side*.25}px`,padding:`${side*.0254}px ${side*.089}px`});
          if(item.cost===null)cost.style.color='rgba(255,255,255,.8)';
          if(item.cost!==null&&!item.affordable)cost.style.filter='grayscale(1)';button.append(cost);
        }
        if(item.progress!==null){const track=document.createElement('div'),fill=document.createElement('div');track.className='tower-rank';fill.style.width=`${item.progress*100}%`;
          place(track,{x:side*.17,y:side*.13-2.5,width:side*.66,height:5});track.append(fill);button.append(track);}
      }
      button.onclick=()=>{
        if(item.id.startsWith('build:'))store.dispatch({type:'buildTower',kind:item.id.slice(6) as TowerKind});
        else if(item.id.startsWith('tier:'))store.dispatch({type:'upgradeTower',branch:Number(item.id.slice(5))});
        else if(item.id.startsWith('path:'))store.dispatch({type:'upgradePath',id:item.id.slice(5)});
        else if(item.id==='placement')store.dispatch({type:'placeTower'});
      };
    }
    const selected=plan.selected;
    if(selected?.details){
      const label=document.createElement('section');label.className='tower-label';label.setAttribute('aria-label',selected.details.name);
      const title=document.createElement('h2'),copy=document.createElement('p');title.textContent=selected.details.name;copy.textContent=selected.details.description;
      label.append(title,copy);root.append(label);
      const frame=(r:Rect)=>({...r,height:r.height*1.15});
      const obstacles=[...Object.values(view.corners),...session.hud.callWavePositions.map(p=>waveLayout(view,p).frame),...plan.buttons.filter(b=>b!==selected).map(b=>frame(b.frame))];
      const position=labelPlacement(frame(selected.frame),view.safeRect,obstacles,width=>{label.style.width=`${width}px`;return label.scrollHeight;});
      if(position){place(label,position.frame);label.tabIndex=0;}else label.remove();
    }
  }
  return {sync,frame,draw(next: HudCanvas){sync(next);frame(next);},destroy(){targets.remove();root.remove();}};
}
