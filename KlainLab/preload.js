'use strict';
const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('labHost', {
  info: () => ipcRenderer.invoke('lab:info'),
  reloadDevices: () => ipcRenderer.invoke('lab:reload'),
  openDevTools: () => ipcRenderer.send('lab:devtools'),
  onFileChanged: (cb) => {
    const listener = (_event, name) => cb(name);
    ipcRenderer.on('lab:file-changed', listener);
    return () => ipcRenderer.removeListener('lab:file-changed', listener);
  },
});
