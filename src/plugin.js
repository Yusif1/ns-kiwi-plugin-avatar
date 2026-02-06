/* global kiwi:true */

import md5 from 'md5';
import * as config from './config.js';

kiwi.plugin('avatar', (kiwi) => {
    config.setDefaults();

    kiwi.on('irc.join', (event, net) => {
        kiwi.Vue.nextTick(() => {
            updateAvatar(net, event.nick);
        });
    });

    kiwi.on('irc.wholist', (event, net) => {
        const nicks = event.users.map((user) => user.nick);
        kiwi.Vue.nextTick(() => {
            nicks.forEach((nick) => {
                updateAvatar(net, nick, false);
            });
        });
    });

    kiwi.on('irc.account', (event, net) => {
        kiwi.Vue.nextTick(() => {
            updateAvatar(net, event.nick, true);
        });
    });

    function updateAvatar(net, nick, _force) {
        const force = !!_force;
        const user = kiwi.state.getUser(net.id, nick);
        if (!user) {
            return;
        }

        if (!force && user.avatar && user.avatar.small) {
            return;
        }

        if (!user.account) { return; }

        const url = md5(user.account);

        setAvatar(user, url);
    }

    function setAvatar(user, _url) {
        const url = _url;

        user.avatar.small = kiwi.state.setting('plugin-avatar.gatewayURL') + '40/' + url + '.png';
        user.avatar.large = kiwi.state.setting('plugin-avatar.gatewayURL') + 'default/' + url + '.png';
    }
});
