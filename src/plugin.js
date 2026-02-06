/* global kiwi:true */

import md5 from 'md5';
import { setDefaults } from './config.js';

kiwi.plugin('avatar', (kiwi) => {
    setDefaults();

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

    function updateAvatar(net, nick, force = false) {
        const user = kiwi.state.getUser(net.id, nick);
        if (!user) {
            return;
        }

        if (!force && user.avatar && user.avatar.small) {
            return;
        }

        if (!user.account) {
            return;
        }

        const hash = md5(user.account);
        setAvatar(user, hash);
    }

    function setAvatar(user, hash) {
        const baseURL = kiwi.state.setting('plugin-avatar.gatewayURL');
        user.avatar.small = baseURL + '40/' + hash + '.png';
        user.avatar.large = baseURL + 'default/' + hash + '.png';
    }
});
