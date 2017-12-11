// module.exports = {
//   // See <http://truffleframework.com/docs/advanced/configuration>
//   // to customize your Truffle configuration!
//   networks: {
//     development: {
//       host: 'localhost',
//       port: '7545',
//       network_id: '*'
//     }
//   }
// };

var HDWalletProvider = require("truffle-hdwallet-provider");
var secrets = require('./secrets.js')

module.exports = {
  // See <http://truffleframework.com/docs/advanced/configuration>
  // to customize your Truffle configuration!
  networks: {
    development: {
      host: 'localhost',
      port: '7545',
      network_id: '*'
    },
    kovan: {
      provider: function() {
        return new HDWalletProvider(secrets.mnemonic, "https://kovan.infura.io/" + secrets.infura, 1)
      },
      network_id: 42,
      gas: 4700000
    },
    rinkeby: {
      provider: function() {
        return new HDWalletProvider(secrets.mnemonic, "https://rinkeby.infura.io/" + secrets.infura)
      },
      network_id: 4
    }
  }
};
