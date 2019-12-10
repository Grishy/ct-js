/* eslint-disable camelcase */
const {app, dialog, BrowserWindow} = require('electron');
let mainWindow;
const createMainWindow = () => {
    mainWindow = new BrowserWindow({
        width: 1024,
        height: 720,
        minWidth: 380,
        minHeight: 380,
        center: true,
        resizable: true,

        title: 'ct.js',
        icon: 'ct_ide.png',

        webPreferences: {
            nodeIntegration: true,
            defaultFontFamily: 'sansSerif',
            backgroundThrottling: true
        }
    });
    mainWindow.loadFile('index.html');
    mainWindow.webContents.openDevTools();

    mainWindow.on('close', e => {
        e.preventDefault();
        dialog.showMessageBox(mainWindow, {
            type: 'question',
            title: 'Exit confirmation',
            message: 'Do you really want to quit?',
            details: 'All the unsaved changes will be lost!',
            buttons: ['Yes', 'No'],
            defaultId: 1
        }).then(res => {
            if (res.response === 0){
                //Yes button pressed
                mainWindow.destroy();
            }
        });
    });
};

app.on('ready', createMainWindow);


app.on('window-all-closed', () => {
    if (process.platform !== 'darwin') {
        app.quit();
    }
});

app.on('activate', () => {
    if (mainWindow === null) {
        createMainWindow();
    }
});
