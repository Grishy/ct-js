const TransformHandle = require('./TransformHandle');
const trigo = require('./../trigo');
const everywhere = {
    contains() {
        return true;
    }
};
/*
Transformer has no local transform changes from Identity matrix.
It uses `this.applyingMatrix` matrix to position its UI elements and, in the end, to change edited items' transforms.
`this.applyingMatrix` always has its x and y set to 0.
Its values are determined by values `appliedScaleX`, `appliedScaleY` and `appliedRotation`
Item displacement is achieved by Transformer's coordinates.
*/
class Transformer extends PIXI.Container {
    constructor(items) {
        if (!items || !items.length) {
            throw new Error('Cannot create a Tramsformer with no items.');
        }
        super();
        this.x = this.y = 0;
        this.items = items;
        this.drag = false;
        this.interactive = true;
        this.hitArea = everywhere; // set a custom hit area so we can detect clicks outside the transform frame

        /* Copy transforms so we don't get misalignment
        due to layered deltas after transforming at each frame */
        this.sourceTransforms = items.map(item => {
            const t = new PIXI.Matrix();
            t.copyFrom(item.localTransform);
            return t;
        });

        this.applyingMatrix = new PIXI.Matrix();
        this.appliedScaleX = this.appliedScaleY = 1;
        this.appliedX = this.appliedY = 0;
        this.appliedRotation = 0;

        this.outline = new PIXI.Graphics();
        this.rotHandle = new TransformHandle('grab');
        this.moveHandle = new TransformHandle('move');
        this.scaleXHandle = new TransformHandle('ew-resize');
        this.scaleXHandleAlt = new TransformHandle('ew-resize');
        this.scaleYHandle = new TransformHandle('ns-resize');
        this.scaleXYHandle = new TransformHandle('nwse-resize');
        this.handles = [this.rotHandle, this.scaleXHandle, this.scaleXHandleAlt, this.scaleYHandle, this.scaleXYHandle, this.moveHandle];
        this.addChild(this.outline, ...this.handles);
        this.realign();

        this.on('pointerdown', this.deleteSelf);
        for (const handle of this.handles) {
            handle.on('pointerdown', this.captureMouseDown.bind(this));
        }
        this.on('pointermove', this.updateState);
        this.on('pointerup', this.stopDragging);
    }
    realign() {
        let bbox;
        for (const item of this.items) {
            const ibbox = item.getLocalBounds();
            ibbox.x += item.x;
            ibbox.y += item.y;
            if (!bbox) {
                bbox = new PIXI.Rectangle(0, 0, 0, 0);
                bbox.copyFrom(ibbox);
            } else {
                bbox.enlarge(ibbox);
            }
        }
        // Position itself so the pivot is placed at the center of the selection.
        this.x = bbox.x + bbox.width / 2;
        this.y = bbox.y + bbox.height / 2;

        const hw = bbox.width / 2; // half-width, half height
        const hh = bbox.height / 2;
        const t = this.applyingMatrix;

        const c = t.apply({
            x: 0,
            y: 0
        });
        const tl = t.apply({
            x: -hw,
            y: -hh
        });
        const tr = t.apply({
            x: hw,
            y: -hh
        });
        const br = t.apply({
            x: hw,
            y: hh
        });
        const bl = t.apply({
            x: -hw,
            y: hh
        });
        this.outline.clear();
        this.outline
        .lineStyle(3, 0x446adb)
        .moveTo(tl.x, tl.y)
        .lineTo(tr.x, tr.y)
        .lineTo(br.x, br.y)
        .lineTo(bl.x, bl.y)
        .lineTo(tl.x, tl.y)
        .closePath();
        this.outline
        .lineStyle(1, 0xffffff)
        .moveTo(tl.x, tl.y)
        .lineTo(tr.x, tr.y)
        .lineTo(br.x, br.y)
        .lineTo(bl.x, bl.y)
        .lineTo(tl.x, tl.y)
        .closePath();

        // Position the handles relative to the target transform matrix
        this.moveHandle.x = c.x;
        this.moveHandle.y = c.y;
        t.apply({
            x: hw,
            y: hh
        }, this.scaleXYHandle.position);
        t.apply({
            x: hw,
            y: 0
        }, this.scaleXHandle.position);
        t.apply({
            x: -hw,
            y: 0
        }, this.scaleXHandleAlt.position);
        t.apply({
            x: 0,
            y: hh
        }, this.scaleYHandle.position);
        t.apply({
            x: hw + 32 / this.appliedScaleX,
            y: 0
        }, this.rotHandle.position);

        this.selectionBounds = bbox;
    }

    deleteSelf() {
        this.parent.removeChild(this);
    }
    captureMouseDown(e) {
        // Previous local transform that will be applied to entities
        this.previousScaleX = this.appliedScaleX;
        this.previousScaleY = this.appliedScaleY;
        this.previousRotation = this.appliedRotation;
        this.xprev = this.appliedX;
        this.yprev = this.appliedY;
        const globPos = this.getGlobalPosition();
        this.drag = {
            fromX: e.data.global.x - globPos.x,
            fromY: e.data.global.y - globPos.y,
            target: e.currentTarget
        };
        e.stopPropagation();
    }
    updateMatrix() {
        this.applyingMatrix.identity();
        this.applyingMatrix.scale(this.appliedScaleX, this.appliedScaleY);
        this.applyingMatrix.rotate(this.appliedRotation);
        this.applyingMatrix.translate(this.appliedX, this.appliedY);
    }
    updateState(e) {
        if (!this.drag) {
            return;
        }
        const globPos = this.getGlobalPosition();
        this.drag.toX = e.data.global.x - globPos.x;
        this.drag.toY = e.data.global.y - globPos.y;
        const hw = this.selectionBounds.width / 2; // half-width, half height
        const hh = this.selectionBounds.height / 2;

        if (this.drag.target === this.rotHandle) {
            const from = trigo.pdnRad(0, 0, this.drag.fromX, this.drag.fromY),
                  to = trigo.pdnRad(0, 0, this.drag.toX, this.drag.toY);
            let delta = trigo.deltaDirRad(from, to);
            // Snap rotation to 15° when shift is pressed
            if (this.state.shift) {
                delta = trigo.degToRad(Math.round(trigo.radToDeg(delta) / 15) * 15);
            }
            this.appliedRotation = this.previousRotation + delta;
            this.updateMatrix();
        } else if (this.drag.target === this.scaleXHandle || this.drag.target === this.scaleXHandleAlt) {
            // straighten mouse coordinates back to unrotated XY axes
            const normalizedFrom = trigo.rotateRad(this.drag.fromX, this.drag.fromY, -this.appliedRotation),
                  normalizedTo = trigo.rotateRad(this.drag.toX, this.drag.toY, -this.appliedRotation);
            // the first component is `x` — that's what we need to get the desired x scale
            const [fromDist] = normalizedFrom; // k === 1;
            const [toDist] = normalizedTo;
            const flip = this.drag.target === this.scaleXHandleAlt? -1 : 1;

            let k = toDist / fromDist;
            if (this.state.shift) {
                k = Math.round(k / 0.1) * 0.1;
            }
            if (!this.state.alt) {
                k = (k - 1) / 2 + 1;
                // Advance the center of the selection so the left/right border stays in place
                this.appliedX = this.xprev + Math.cos(this.appliedRotation) * hw * (k - 1) * flip;
                this.appliedY = this.yprev + Math.sin(this.appliedRotation) * hh * (k - 1) * flip;
            } else {
                this.appliedX = this.xprev;
                this.appliedY = this.yprev;
            }
            this.appliedScaleX = this.previousScaleX * k;
            this.updateMatrix();
        }
        this.realign();
    }
    stopDragging() {
        this.drag = false;
    }
}

module.exports = Transformer;