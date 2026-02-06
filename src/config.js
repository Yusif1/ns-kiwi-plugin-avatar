/* global kiwi:true */

export function setDefaults() {
    setSettingDefault('plugin-avatar.gatewayURL', 'https://www.simosnap.org/uploads/avatars/');
}

function setSettingDefault(name, value) {
    const settingKey = 'settings.' + name;
    if (kiwi.state.getSetting(settingKey) === undefined) {
        kiwi.state.setSetting(settingKey, value);
    }
}
