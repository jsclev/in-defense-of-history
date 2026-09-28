import { expect, it, vi } from 'vitest';
import type Phaser from 'phaser';
import { ImagePool } from '../src/game/image-pool';
import { ImageUpdates } from '../src/game/image-updates';

it('leases inactive images without allocating again and reapplies frame, size, depth, opacity and rotation',()=>{
  const members:ReturnType<typeof make>[]=[];
  function make(){return {active:true,setActive:vi.fn(function(this:{active:boolean},v:boolean){this.active=v;return this;}),setVisible:vi.fn().mockReturnThis(),
    ...Object.fromEntries(['setTexture','setOrigin','setPosition','setDisplaySize','setDepth','setRotation','setAlpha'].map(k=>[k,vi.fn().mockReturnThis()]))};}
  const group={add:(image:ReturnType<typeof make>)=>members.push(image),getFirstDead:()=>members.find(i=>!i.active)??null,
    killAndHide:(image:ReturnType<typeof make>)=>{image.setActive(false);image.setVisible!(false);}};
  const scene={add:{group:vi.fn(()=>group),image:vi.fn(make)}};
  const pool=new ImagePool(scene as unknown as Phaser.Scene),updates=new ImageUpdates();
  const first=pool.acquire('shot'),second=pool.acquire('shot');expect(first).not.toBe(second);
  const p={key:'shot',x:10,y:20,width:4,height:8,originX:.5,originY:.5,depth:21,rotation:1,alpha:.2};
  updates.apply(first,p);pool.release(first);
  expect(first.setVisible).toHaveBeenLastCalledWith(false);
  const reused=pool.acquire('explosion','2');expect(reused).toBe(first);expect(scene.add.image).toHaveBeenCalledTimes(2);
  updates.apply(reused,{...p,key:'explosion',frame:'2',width:80,height:80,depth:10.9,rotation:0,alpha:1});
  expect(reused.setTexture).toHaveBeenLastCalledWith('explosion','2');expect(reused.setDisplaySize).toHaveBeenLastCalledWith(80,80);
  expect(reused.setAlpha).toHaveBeenLastCalledWith(1);expect(reused.setRotation).toHaveBeenLastCalledWith(0);expect(reused.setDepth).toHaveBeenLastCalledWith(10.9);
  expect(reused.setVisible).toHaveBeenLastCalledWith(true);expect(reused.active).toBe(true);
});
