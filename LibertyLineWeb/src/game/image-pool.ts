import type Phaser from 'phaser';

// Groups do not change display order. Inactive, invisible images stay available
// until Scene shutdown; ImageUpdates applies every new lease's visual state.
export class ImagePool {
  private readonly group: Phaser.GameObjects.Group;
  constructor(private readonly scene: Phaser.Scene) { this.group=scene.add.group({runChildUpdate:false}); }
  acquire(key: string, frame?: string): Phaser.GameObjects.Image {
    let image=this.group.getFirstDead(false) as Phaser.GameObjects.Image | null;
    if(!image){image=this.scene.add.image(0,0,key,frame);this.group.add(image);}
    image.setActive(true).setVisible(true);
    return image;
  }
  release(image: Phaser.GameObjects.Image) { this.group.killAndHide(image); }
}
