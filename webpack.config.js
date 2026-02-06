const path = require('path');

module.exports = (env, argv) => {
    const isProd = argv.mode === 'production';

    return {
        entry: './src/plugin.js',
        output: {
            filename: 'ns-kiwi-plugin-avatar.js',
            path: path.resolve(__dirname, 'dist'),
            clean: true,
        },
        module: {
            rules: [
                {
                    test: /\.js$/,
                    use: ['babel-loader'],
                    include: [
                        path.join(__dirname, 'src'),
                    ],
                },
            ],
        },
        devtool: isProd ? false : 'source-map',
        devServer: {
            static: {
                directory: path.join(__dirname, 'dist'),
            },
            compress: true,
            port: 9000,
        },
    };
};