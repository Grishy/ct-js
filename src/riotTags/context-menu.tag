context-menu(class="{opened: opts.menu.opened}" ref="root")
    label(each="{item in opts.menu.items}" class="{item.type || 'item'} {checkbox: item.type === 'checkbox'} {submenu: item.submenu}" disabled="{item.disabled}" onclick="{onItemClick}")
        i(class="icon-{item.icon instanceof Function? item.icon() : item.icon}" if="{item.icon && item.type !== 'separator' && item.type !== 'checkbox'}")
        input(type="checkbox" checked="{item.checked}" if="{item.type === 'checkbox'}")
        span(if="{!item.type !== 'separator'}") {item.label}
        context-menu(if="{item.submenu && item.type !== 'separator'}" menu="{item.submenu}")
    script.
        var noFakeClicks;
        this.onItemClick = e => {
            if (e.item.item.click) { // first `item` is a riot's reference to all looped vars, second is var's name in markup
                e.item.item.click();
            }
            if (!e.item.item.submenu) { // autoclose on regular items
                this.opts.menu.opened = false;
            } else if (e.target.closest('context-menu') === this.root) { // prevent closing if a label with a submenu was clicked *directly*
                e.stopPropagation();
            }
        };

        this.popup = (x, y) => {
            noFakeClicks = true;
            setTimeout(() => {
                noFakeClicks = false;
            }, 100);
            y -= this.root.parentNode.getBoundingClientRect().y;
            if (x !== void 0 && y !== void 0) {
                this.root.style.left = x + 'px';
                this.root.style.top = y + 'px';
            }
            this.opts.menu.opened = true;
            this.update();
        };

        this.toggle = () => {
            this.opts.menu.opened = !this.opts.menu.opened;
            if (this.opts.menu.opened) {
                noFakeClicks = true;
                setTimeout(() => {
                    noFakeClicks = false;
                }, 100);
            }
            this.update();
        };
        this.open = () => {
            noFakeClicks = true;
            setTimeout(() => {
                noFakeClicks = false;
            }, 100);
            this.opts.menu.opened = true;
            this.update();
        };
        this.close = () => {
            this.opts.menu.opened = false;
            this.update();
        };
        const clickListener = e => {
            if (!this.opts.menu.opened || noFakeClicks) {
                return;
            }
            if (e.target.closest('context-menu') !== this.root) {
                this.opts.menu.opened = false;
                this.update();
            } else {
                e.stopPropagation();
            }
        }
        this.on('mount', () => {
            document.addEventListener('click', clickListener);
        });
        this.on('unmount', () => {
            document.removeEventListener('click', clickListener);
        });
