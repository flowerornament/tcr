
import ERC20Artifacts from '../../build/contracts/ERC20.json'
// import ERC20Artifacts from '../../build/contracts/AeternityToken.json'
import TCRArtifacts from '../../build/contracts/TCR.json'

import Web3 from 'web3'
const BN = Web3.utils.BN
import ZeroClientProvider from 'web3-provider-engine/zero.js'
import IdManagerProvider from '@aeternity/id-manager-provider'

class TCR {
  constructor (options) {

    this.TCR = null

    this.connected = false
    this.pollingInterval = null
    this.account = null
    this.unlocked = false
    this.balanceWei = 0
    this.tokenBalance = 0
    this.balance = 0
    this.started = false
    this.addresses = {
      42: '0x460aaba70762ec12caaf41edf974351d37708111', // kovan
      4: '0x6afcaaaee997ab0c1b8d2e1977699815478113ab', // rinkeby
      4447: '0xf25186b5081ff5ce73482ad761db0eb0d25abfbf'
    }
    this.tokenAddresses = {
      42: '0x35d8830ea35e6Df033eEdb6d5045334A4e34f9f9', // AE
      4: '0xcc0604514f71b8d39e13315d59f4115702b42646', //
      4447: '0x345ca3e014aaf5dca488057592ee47305d9b3e10'
    }
    // this.address = '0xf25186b5081ff5ce73482ad761db0eb0d25abfbf'
    // this.address = '0x7c08ffd5a25fca0e123d8762d014173e87a52522'
    // this.tokenAddress = '0x345ca3e014aaf5dca488057592ee47305d9b3e10'
    // this.tokenAddress = '0xcc0604514f71b8d39e13315d59f4115702b42646'
    this.genesisBlock = 0
    this.loading = false
    this.network = null
    this.options = {
      autoInit: true,
      getPastEvents: false,
      watchFutureEvents: false,
      connectionRetries: 3
    }
    Object.assign(this.options, options)
    if (this.options.autoInit) this.initWeb3()
  }

  // hello world : )
  helloWorld () {
    console.log('hello world!')
  }

  /*
   * Connect
   */

  initWeb3 () {
    return new Promise((resolve, reject) => {

      let web3Provider = false
      let idManager = new IdManagerProvider()

      idManager.checkIdManager().then((idManagerPresent)=>{
				// check for aedentity app
        if (idManagerPresent) {
          web3Provider = idManager.web3.currentProvider

          // check for metamask
        } else if (global.web3) {
          web3Provider = web3.currentProvider

          // attempt to try again if no aedentity app or metamask
        } else if (this.options.connectionRetries > 0){
          this.options.connectionRetries -= 1
          setTimeout(() => {
            this.initWeb3().then(resolve).catch((error) => {
              reject(new Error(error))
            })
          }, 1000)
          // revert to a read only version using infura endpoint
        } else {
          this.readOnly = true
          web3Provider = ZeroClientProvider({
            getAccounts: function(){},
            // rpcUrl: 'https://mainnet.infura.io',
            // rpcUrl: 'https://testnet.infura.io',
            rpcUrl: 'https://rinkeby.infura.io',
            // rpcUrl: 'https://kovan.infura.io',
          })
        }

        if (web3Provider && !this.started) {
          this.connected = true
          global.web3 = new Web3(web3Provider)
          this.startChecking()

          if (this.options.getPastEvents) this.getPastEvents()
          if (this.options.watchFutureEvents) this.watchFutureEvents()
        }
      })
    })
  }

  /*
   * Check every second for switching network or wallet
   */

  startChecking () {
    this.started = true
    if (global.pollingInterval) clearInterval(global.pollingInterval)
    this.getGenesisBlock()
    .then(this.check.bind(this))
    .then(() => {
      global.pollingInterval = setInterval(this.check.bind(this), 5000)
    })
    .catch((err) => {
      throw new Error(err)
    })
  }

  check () {
    this.checkNetwork()
    .then(this.checkAccount.bind(this))
    .then(this.checkBalance.bind(this))
    .catch((error) => {
      console.error(error)
      throw new Error(error)
    })
  }

  checkNetwork () {
    return global.web3.eth.net.getId((err, netId) => {
      if (err) console.error(err)
      if (!err && this.network !== netId) {
        this.network = netId
        return this.deployContract()
      }
    })
  }
  
  deployContract () {
    let address = this.addresses[this.network]
    let tokenAddress = this.tokenAddresses[this.network]
    this.ERC20 = new global.web3.eth.Contract(ERC20Artifacts.abi, tokenAddress)
    this.TCR = new global.web3.eth.Contract(TCRArtifacts.abi, address)
  }

  checkAccount () {
    return global.web3.eth.getAccounts((error, accounts) => {
      if (error) throw new Error(error)
      if (accounts.length && this.account !== accounts[0]) {
        this.unlocked = true
        this.account = accounts[0]
      } else if (!accounts.length) {
        this.unlocked = false
        this.account = null
      }
    })
  }

  checkBalance () {
    if (!this.account) return new Error('Unlock Wallet')
    return global.web3.eth.getBalance(this.account, (error, balance) => {
      if (error) throw new Error(error)
      if (balance !== this.balance) this.balance = balance
      return this.balanceOf().then((balance) => {
        // balance = (parseInt(balance) / 1000000000000000000).toString()
        if (balance !== this.tokenBalance) this.tokenBalance = balance
      })
    })
  }


  /*
   * Not Yet Implemented vvvv
   */

  getGenesisBlock () {
    return new Promise((resolve, reject) => {
      resolve()
    })
  }

  getPastEvents () {
    return new Promise((resolve, reject) => {
      resolve()
    })
  }

  watchFutureEvents () {
    return new Promise((resolve, reject) => {
      resolve()
    })
  }




  /*
   *
   * Constant Functions
   *
   */

  getChallenge (index, statementHash) {
    return this.TCR.methods.getChallenge(new BN(index, 10), statementHash).call()
      .then((resp) => {
      console.log(resp)
      return resp
    }).catch((err) => {
      console.error(err)
    })
  }
  isApproved (statementHash) {
    return this.TCR.methods.isApproved(statementHash).call()
  }
  isChallenged (statementHash) {
    return this.TCR.methods.isChallenged(statementHash).call()
      .then((resp) => {
      console.log(resp)
      return resp
    }).catch((err) => {
      console.error(err)
    })
  }
  getEntry (index) {
    return this.TCR.methods.getEntry(new BN(index, 10)).call()
  }
  getListLength () {
    if(!this.TCR) return new Promise((resolve, reject) => reject(new Error('Not deployed yet')))
    return this.TCR.methods.getListLength().call()
    .then((resp) => {
      return resp
    }).catch((err) => {
      console.error(err)
    })
  }
  getVotes (statementHash, challengeDate) {
    return this.TCR.methods.getVotes(statementHash, new BN(challengeDate, 10)).call()
      .then((resp) => {
      console.log(resp)
      return resp
    }).catch((err) => {
      console.error(err)
    })
  }

  /*
   *
   * Transaction Functions
   *
   */

  initiateChallenge (statementHash) {
    if (!this.account) return new Error('Unlock Wallet')
    return this.TCR.methods.initiateChallenge(statementHash).send({from: this.account})
    .on('transactionHash', (hash) => {
      console.log(hash)
      this.loading = true
    })
      .then((resp) => {
      this.loading = false
      console.log(resp)
      return resp
    }).catch((err) => {
      this.loading = false
      console.error(err)
    })
  }
  castVote (statementHash, votedYes, amount) {
    if (!this.account) return new Error('Unlock Wallet')
    return this.TCR.methods.castVote(statementHash, votedYes, new BN(amount, 10)).send({from: this.account})
    .on('transactionHash', (hash) => {
      console.log(hash)
      this.loading = true
    })
      .then((resp) => {
      this.loading = false
      console.log(resp)
      return resp
    }).catch((err) => {
      this.loading = false
      console.error(err)
    })
  }
  dispense (statementHash, challengeDate) {
    console.log(statementHash, challengeDate)
    if (!this.account) return new Error('Unlock Wallet')
    return this.TCR.methods.dispense(statementHash, new BN(challengeDate, 10)).call()
    // .on('transactionHash', (hash) => {
    //   console.log(hash)
    //   this.loading = true
    // })
    .then((resp) => {
      this.loading = false
      console.log(resp)
      return resp
    }).catch((err) => {
      this.loading = false
      console.error(err)
    })
  }
  applyToList (statement) {
    console.log(statement)
    if (!this.account) return new Error('Unlock Wallet')
    return this.TCR.methods.applyToList(statement).send({from: this.account})
    .on('transactionHash', (hash) => {
      console.log(hash)
      this.loading = true
    })
      .then((resp) => {
      this.loading = false
      console.log(resp)
      return resp
    }).catch((err) => {
      this.loading = false
      console.error(err)
    })
  }
  balanceOf () {
    if (!this.account) return new Promise((resolve, reject) => reject(Error('Unlock Wallet')))
    return this.ERC20.methods.balanceOf(this.account).call()
  }
  allowance () {
    if (!this.account) return new Promise((resolve, reject) => reject(Error('Unlock Wallet')))
    return this.ERC20.methods.allowance(this.account, this.addresses[this.network]).call()
  }
  mint (address, amount) {
    if (!this.account) return new Error('Unlock Wallet')
    return this.ERC20.methods.mint(address, new BN(amount)).send({from: this.account})
    .on('transactionHash', (hash) => {
      console.log(hash)
      this.loading = true
    })
      .then((resp) => {
      this.loading = false
      console.log(resp)
      return resp
    }).catch((err) => {
      this.loading = false
      console.error(err)
    })
  }
  approve (amount) {
    if (!this.account) return new Error('Unlock Wallet')
    let address = this.addresses[this.network]
    return this.ERC20.methods.approve(address, new BN(amount)).send({from: this.account})
    .on('transactionHash', (hash) => {
      console.log(hash)
      this.loading = true
    })
      .then((resp) => {
      this.loading = false
      console.log(resp)
      return resp
    }).catch((err) => {
      this.loading = false
      console.error(err)
    })
  }

  /*
   *
   * Events
   *
   */




}

export default TCR
