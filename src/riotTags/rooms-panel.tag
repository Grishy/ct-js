rooms-panel.panel.view
    .flexfix.tall
        .flexfix-header
            div
                .toright
                    b {vocGlob.sort}
                    button.inline.square(onclick="{switchSort('date')}" class="{selected: sort === 'date' && !searchResults}")
                        svg.feather
                            use(xlink:href="data/icons.svg#clock")
                    button.inline.square(onclick="{switchSort('name')}" class="{selected: sort === 'name' && !searchResults}")
                        svg.feather
                            use(xlink:href="data/icons.svg#sort-alphabetically")
                    .aSearchWrap
                        input.inline(type="text" onkeyup="{fuseSearch}")
                        svg.feather
                            use(xlink:href="data/icons.svg#search")
                    button.inline.square(onclick="{switchLayout}")
                        svg.feather
                            use(xlink:href="data/icons.svg#{localStorage.roomsLayout === 'list'? 'grid' : 'list'}")
                .toleft
                    button#roomcreate(onclick="{roomCreate}" data-hotkey="Control+n" title="Control+N")
                        svg.feather
                            use(xlink:href="data/icons.svg#plus")
                        span {voc.create}
        ul.cards.rooms.flexfix-body(class="{list: localStorage.roomsLayout === 'list'}")
            li(
                each="{room in (searchResults? searchResults : rooms)}"
                class="{starting: window.currentProject.startroom === room.uid}"
                onclick="{openRoom(room)}"
                oncontextmenu="{menuPopup(room)}"
                onlong-press="{menuPopup(room)}"
            )
                img(src="file://{sessionStorage.projdir + '/img/r' + room.thumbnail + '.png?' + room.lastmod}")
                span {room.name}
                span.date(if="{room.lastmod}") {niceTime(room.lastmod)}
                svg.feather(if="{window.currentProject.startroom === room.uid}")
                    use(xlink:href="data/icons.svg#play")
    room-editor(if="{editing}" room="{editingRoom}")
    context-menu(menu="{roomMenu}" ref="roomMenu")
    script.
        const generateGUID = require('./data/node_requires/generateGUID');

        this.namespace = 'rooms';
        this.mixin(window.riotVoc);
        this.mixin(window.riotNiceTime);
        this.editing = false;
        this.sort = 'name';
        this.sortReverse = false;

        this.updateList = () => {
            this.rooms = [...window.currentProject.rooms];
            if (this.sort === 'name') {
                this.rooms.sort((a, b) => {
                    return a.name.localeCompare(b.name);
                });
            } else {
                this.rooms.sort((a, b) => {
                    return b.lastmod - a.lastmod;
                });
            }
            if (this.sortReverse) {
                this.rooms.reverse();
            }
        };
        this.switchSort = sort => e => {
            if (this.sort === sort) {
                this.sortReverse = !this.sortReverse;
            } else {
                this.sort = sort;
                this.sortReverse = false;
            }
            this.updateList();
        };
        this.switchLayout = e => {
            localStorage.roomsLayout = localStorage.roomsLayout === 'list'? 'grid' : 'list';
        };
        const fuseOptions = {
            shouldSort: true,
            tokenize: true,
            threshold: 0.5,
            location: 0,
            distance: 100,
            maxPatternLength: 32,
            minMatchCharLength: 1,
            keys: ['name']
        };
        const Fuse = require('fuse.js');
        this.fuseSearch = e => {
            if (e.target.value.trim()) {
                var fuse = new Fuse(this.rooms, fuseOptions);
                this.searchResults = fuse.search(e.target.value.trim());
            } else {
                this.searchResults = null;
            }
        };
        this.setUpPanel = e => {
            this.updateList();
            this.searchResults = null;
            this.editing = false;
            this.editingRoom = null;
            this.update();
        };
        window.signals.on('projectLoaded', this.setUpPanel);
        this.on('mount', this.setUpPanel);
        this.on('unmount', () => {
            window.signals.off('projectLoaded', this.setUpPanel);
        });

        const fs = require('fs-extra'),
              path = require('path');
        this.roomCreate = function (e) {
            if (this.editing) {
                return false;
            }
            var guid = generateGUID(),
                thumbnail = guid.split('-').pop();
            fs.copy('./data/img/notexture.png', path.join(sessionStorage.projdir, '/img/r' + thumbnail + '.png'), () => {
                var newRoom = {
                    name: 'Room_' + thumbnail,
                    oncreate: '',
                    onstep: '',
                    ondraw: '',
                    onleave: '',
                    width: 800,
                    height: 600,
                    backgrounds: [],
                    copies: [],
                    tiles: [],
                    uid: guid,
                    thumbnail: thumbnail
                };
                window.currentProject.rooms.push(newRoom);
                this.openRoom(newRoom)();
                this.updateList();
                this.update();
            });
        };
        this.openRoom = room => e => {
            this.editingRoom = room;
            this.editing = true;
        };

        this.roomMenu = {
            items: [{
                label: this.voc.makestarting,
                click: () => {
                    window.currentProject.startroom = this.editingRoom.uid;
                    this.update();
                }
            }, {
                label: window.languageJSON.common.open,
                click: () => {
                    this.openRoom(this.editingRoom)();
                    this.update();
                }
            }, {
                label: languageJSON.common.copyName,
                click: e => {
                    const {clipboard} = require('electron');
                    clipboard.writeText(this.editingRoom.name);
                }
            }, {
                label: window.languageJSON.common.duplicate,
                click: () => {
                    alertify
                    .defaultValue(this.editingRoom.name + '_dup')
                    .prompt(window.languageJSON.common.newname)
                    .then(e => {
                        if (e.inputValue != '' && e.buttonClicked !== 'cancel') {
                            var guid = generateGUID(),
                                thumbnail = guid.split('-').pop();
                            var newRoom = JSON.parse(JSON.stringify(this.editingRoom));
                            newRoom.name = e.inputValue;
                            window.currentProject.rooms.push(newRoom);
                            newRoom.uid = guid;
                            newRoom.thumbnail = thumbnail;
                            fs.linkSync(sessionStorage.projdir + '/img/r' + this.editingRoom.thumbnail + '.png', sessionStorage.projdir + '/img/r' + thumbnail + '.png')
                            this.updateList();
                            this.update();
                        }
                    });
                }
            }, {
                label: window.languageJSON.common.rename,
                click: () => {
                    alertify
                    .defaultValue(this.editingRoom.name)
                    .prompt(window.languageJSON.common.newname)
                    .then(e => {
                        if (e.inputValue != '' && e.buttonClicked !== 'cancel') {
                            var nam = e.inputValue;
                            this.editingRoom.name = nam;
                            this.update();
                        }
                    });
                }
            }, {
                type: 'separator'
            }, {
                label: window.languageJSON.common.delete,
                click: () => {
                    alertify
                    .confirm(window.languageJSON.common.confirmDelete.replace('{0}', this.editingRoom.name))
                    .then(e => {
                        if (e.buttonClicked === 'ok') {
                            var ind = window.currentProject.rooms.indexOf(this.editingRoom);
                            window.currentProject.rooms.splice(ind, 1);
                            this.updateList();
                            this.update();
                            alertify
                            .okBtn(window.languageJSON.common.ok)
                            .cancelBtn(window.languageJSON.common.cancel);
                        }
                    });
                }
            }]
        };

        this.menuPopup = room => e => {
            this.editingRoom = room;
            this.refs.roomMenu.popup(e.clientX, e.clientY);
            e.preventDefault();
        };
