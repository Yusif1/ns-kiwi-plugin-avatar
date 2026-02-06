/* global kiwi:true */

export function setDefaults() {
    setSettingDefault('plugin-avatar.gatewayURL', 'https://www.simosnap.org/uploads/avatars/');
}

function setSettingDefault(name, defaultValue) {
    if (kiwi.state.getSetting('settings.' + name) === undefined) {
        kiwi.state.setSetting('settings.' + name, defaultValue);
    }
}
