import type Phaser from 'phaser';
import type { actorPlan } from './actors';
import type { moralePlan } from './combat-view';

type Plan = ReturnType<typeof actorPlan>;
type Morale = ReturnType<typeof moralePlan> | null;

// Geometry is local to the actor's feet. Walking moves retained commands rather
// than clearing and rebuilding them. Animated morale still updates its fill.
export class ActorMarks {
  private previous: unknown[] = [];
  private x = NaN; private y = NaN; private depth = NaN;
  private visible: boolean | undefined;
  constructor(readonly graphics: Phaser.GameObjects.Graphics) {}
  update(p: Plan, morale: Morale, healthMinimum: number) {
    const g=this.graphics, visible=p.selected || p.health<1 || morale?.visible===true;
    if(visible!==this.visible){g.setVisible(visible);this.visible=visible;}
    if(!visible)return;
    if(this.x!==p.foot.x||this.y!==p.foot.y){g.setPosition(p.foot.x,p.foot.y);this.x=p.foot.x;this.y=p.foot.y;}
    if(this.depth!==p.depth+.00001){this.depth=p.depth+.00001;g.setDepth(this.depth);}
    const inputs=[p.healthOffset.x,p.healthOffset.y,p.selectionOffsetY,p.healthRect.width,p.healthRect.height,healthMinimum,p.health,p.kind,p.selected,
      p.selection.radius,p.selection.width,morale?.visible,
      ...(morale?.visible?[morale.x,morale.y,morale.radius,morale.start,morale.end,morale.fillEnd,morale.fraction,morale.trackWidth,morale.fillWidth]:[])];
    if(inputs.length===this.previous.length&&inputs.every((v,i)=>v===this.previous[i]))return;
    this.previous=inputs;g.clear();
    if(morale?.visible){
      const arc=(width:number,color:number,end:number)=>{
        g.lineStyle(width,color).beginPath().arc(morale.x,morale.y,morale.radius,morale.start,end,false).strokePath();
        for(const angle of [morale.start,end])g.fillStyle(color).fillCircle(morale.x+Math.cos(angle)*morale.radius,morale.y+Math.sin(angle)*morale.radius,width/2);
      };
      arc(morale.trackWidth,0x102438,morale.end);if(morale.fraction>0)arc(morale.fillWidth,0x36dafa,morale.fillEnd);
    }
    if(p.selected)g.lineStyle(p.selection.width,0xffff00,.9).strokeCircle(0,p.selectionOffsetY,p.selection.radius);
    if(p.health<1){
      const r=p.healthRect,{x,y}=p.healthOffset;
      g.lineStyle(r.height/healthMinimum,0x102438).strokeRoundedRect(x,y,r.width,r.height,r.height/2);
      g.fillStyle(0xff0000).fillRoundedRect(x,y,r.width,r.height,r.height/2);
      g.fillStyle(p.kind==='militia'?0x007aff:0x00ff00).fillRoundedRect(x,y,r.width*Math.max(0,p.health),r.height,r.height/2);
    }
  }
}
