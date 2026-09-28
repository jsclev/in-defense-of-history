import { expect, it, vi } from 'vitest';
import type Phaser from 'phaser';
import { ImageUpdates, type ImagePlacement } from '../src/game/image-updates';

it('leaves unchanged images untouched, changes moving depth and restores size/origin after frame changes', () => {
  const image=Object.fromEntries(['setTexture','setOrigin','setPosition','setDisplaySize','setDepth','setRotation','setAlpha']
    .map(key=>[key,vi.fn()]));
  const updates=new ImageUpdates(), node=image as unknown as Phaser.GameObjects.Image;
  const placement:ImagePlacement={key:'atlas',frame:'0',x:10,y:20,width:30,height:40,originX:.5,originY:1,depth:11};
  updates.apply(node,placement);
  for(const fn of Object.values(image))fn.mockClear();
  updates.apply(node,{...placement});
  for(const fn of Object.values(image))expect(fn).not.toHaveBeenCalled();
  updates.apply(node,{...placement,x:12,depth:12});
  expect(image.setPosition).toHaveBeenCalledWith(12,20);expect(image.setDepth).toHaveBeenCalledWith(12);
  expect(image.setTexture).not.toHaveBeenCalled();expect(image.setDisplaySize).not.toHaveBeenCalled();
  updates.apply(node,{...placement,frame:'1'});
  expect(image.setTexture).toHaveBeenCalledWith('atlas','1');
  expect(image.setOrigin).toHaveBeenCalledWith(.5,1);expect(image.setDisplaySize).toHaveBeenCalledWith(30,40);
  updates.apply(node,{...placement,key:'other',originX:0,originY:0,width:40,height:50,rotation:.2,alpha:.3});
  expect(image.setTexture).toHaveBeenCalledWith('other','0');expect(image.setRotation).toHaveBeenCalledWith(.2);expect(image.setAlpha).toHaveBeenCalledWith(.3);
  updates.apply(node,{...placement,key:'other',originX:1,originY:.5,width:41,height:51});
  expect(image.setOrigin).toHaveBeenLastCalledWith(1,.5);expect(image.setDisplaySize).toHaveBeenLastCalledWith(41,51);
  expect(image.setRotation).toHaveBeenLastCalledWith(0);expect(image.setAlpha).toHaveBeenLastCalledWith(1);
});
