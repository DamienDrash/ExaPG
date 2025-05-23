const path = require('path');

module.exports = {
    resolve: {
        extensions: ['.ts', '.tsx', '.js', '.jsx', '.json'],
        modules: [path.resolve(__dirname, 'src'), 'node_modules']
    }
}; 