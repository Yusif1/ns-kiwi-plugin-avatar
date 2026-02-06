# Avatar Plugin for [Kiwi IRC](https://kiwiirc.com)

This plugin adds avatar support to KiwiIRC using a webircgateway plugin to make server-side SQL queries.

It has been designed to work with Anope but will likely work with other services databases too.

#### Dependencies
* Node.js (https://nodejs.org/)
* npm or yarn (https://yarnpkg.com/)

#### Building and installing

1. Build the plugin

   ```console
   $ npm install
   $ npm run build
   ```

   The plugin will then be created at `dist/ns-kiwi-plugin-avatar.js`

2. Copy the plugin to your Kiwi webserver

   The plugin file must be loadable from a webserver. Creating a `plugins/` folder with your KiwiIRC files is a good place to put it.

3. Add the plugin to KiwiIRC

   In your kiwi `config.json` file, find the `plugins` section and add:
   ```json
   {"name": "avatar", "url": "/plugins/ns-kiwi-plugin-avatar.js"}
   ```

#### Configuration

```json
"plugin-avatar": {
    "gatewayURL": "https://www.simosnap.org/uploads/avatars/"
}
```

## License

[Licensed under the Apache License, Version 2.0](LICENSE).
