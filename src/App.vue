<template>
  <div id="app">
    <!-- <router-view/> -->
    <div style="position:absolute" v-if="loading">Loading...</div>
    <div style="margin-top:2em;">
      <div v-text="balance + ' ETH'"></div>
      <div v-text="tokenBalance + ' AE'"></div>
    </div>
    <form @submit.prevent="submit">
      <input placeholder="ask a question" v-model="statement">
    </form>
    <div v-for="entry in whitelist">
      <h1>{{entry.statement}}</h1>
      <h2>{{status(entry.statementHash)}}</h2>
      <!-- <div>statementHash: {{entry.statementHash}}</div>
      <div>lister: {{entry.lister}}</div>
      <div>dateAdded: {{entry.dateAdded}}</div>
      <div>challengeKeysLength: {{entry.challengeKeysLength}}</div>
      <div>exists: {{entry.exists}}</div> -->
      <button @click="initiateChallenge(entry.statementHash)">Challenge</button>
      <div v-if="status(entry.statementHash) === 'challenged'">
          <input v-model="amount"></input>
          <button @click="voteYes(entry.statementHash)">KEEP</button>
          <button @click="voteNo(entry.statementHash)">REMOVE</button>
      </div>
      <div v-if="entry.challengeKeysLength > 0 && status(entry.statementHash) === 'yes' || status(entry.statementHash) === 'no'">
          <div v-for="i in parseInt(entry.challengeKeysLength)" :key="getChallengeDate(entry.statementHash, i)"><button @click="withdraw(entry.statementHash, i)">Dispense Winnings from Challenge Number {{i}}</button></div>
      </div>
      <hr>
    </div>
  </div>
</template>

<script>
import utils from 'web3-utils'
import TCR from '../dapp-scratch-wrapper/TCR/index.js'
let tcr = new TCR()
tcr.helloWorld()
global.tcr = tcr // CL

export default {
  name: 'app',
  data () {
    return {
      balance: 0,
      tokenBalance: 0,
      loading: false,
      whitelist: [],
      challenges: [],
      statement: '',
      amount: 0,
      waitPeriod: (60 * 5),
      timeoutTime: 2000,
      // waitPeriod: (60 * 60) * 48,
      // challengePeriod: (60 * 60) * 24
      challengePeriod: (60 * 2),
      submitAmount: 5
    }
  },
  mounted () {
    this.interval = setInterval(this.checkAccounts, 3000)
    setTimeout(this.begin, 3000)
  },
  methods: {
    checkAccounts () {
      this.balance = utils.fromWei(tcr.balance)
      this.tokenBalance = tcr.tokenBalance
    },
    status (statementHash) {
      let entry = this.whitelist.find((entry) => entry.statementHash === statementHash)
      if (!entry) return 'Not Found'
      let now = new Date().getTime() / 1000
      // wait period is still happening
      // options maybe or challenged
      if ((entry.dateAdded + this.waitPeriod) >= now) {
        if (entry.challengeKeysLength > 0) {
          // there's a challenge
          // make sure it's not a stale one
          // if it's stale return maybe
          // if it's fresh return challenged
          let challenges = this.challenges.filter((chal) => chal.statementHash === entry.statementHash)
          .sort((a, b) => (b.dateChallenged - a.dateChallenged))
          if (challenges.length) {
            if (challenges[0].dateChallenged < entry.dateAdded) {
              return 'maybe'
            } else if (challenges[0].dateChallenged + this.challengePeriod > now) {
              return 'challenged'
            } else {
              return 'maybe' // shouldn't be reachable but is
            }
          } else {
            return 'maybe'
          }
        } else {
          return 'maybe'
        }
      } else {
        // wait period is over
        // options are challenged, yes or no
        if (parseInt(entry.challengeKeysLength) > 0) {
          // theres a challenge
          // if it's stale, then it's not challenged, and return yes
          // if it's fresh, see if it's over
          // if not over, return challenged
          // if it is over return yes or no
          let challenges = this.challenges.filter((chal) => chal.statementHash === entry.statementHash)
          .sort((a, b) => (b.dateChallenged - a.dateChallenged))
          // if (entry.statement === 'third') console.log(challenges.map(chal => { return { votesYes: chal.votesYes, votesNo: chal.votesNo } }))
          if (challenges.length) {
            // stale, not actually challenged
            if (challenges[0].dateChallenged < entry.dateAdded) {
              return 'yes'
            } else if (challenges[0].dateChallenged + this.challengePeriod > now) {
              return 'challenged'
            } else if (challenges[0].votesNo > challenges[0].votesYes) {
              return 'no'
            } else {
              return 'yes'
            }
          } else {
            return 'yes'
          }
        } else {
          return 'yes'
        }
      }
    },
    begin () {
      if (!tcr.connected) {
        setTimeout(this.begin, this.timeoutTime)
      } else {
        this.whitelist = []
        return tcr.getListLength().then((length) => {
          return this.getEntry(0, length)
          .catch((err) => {
            console.log(err)
          })
        }).catch((err) => {
          console.log(err)
        })
      }
    },
    getEntry (key = 0, length) {
      if (key < length) {
        return tcr.getEntry(key).then((res) => {
          res.dateAdded = parseInt(res.dateAdded)
          this.whitelist.unshift(res)
          if (res.challengeKeysLength > 0) {
            return this.getChallenge(res.statementHash, 0, res.challengeKeysLength).then(() => {
              return this.getEntry(key + 1, length)
            })
          } else {
            return this.getEntry(key + 1, length)
          }
        })
      } else {
        return new Promise((resolve, reject) => resolve())
      }
    },
    getChallenge (statementHash, key, length) {
      return new Promise((resolve, reject) => {
        if (key >= length) return resolve()
        tcr.getChallenge(key, statementHash).then((res) => {
          res.dateChallenged = parseInt(res.dateChallenged)
          res.votesYes = parseInt(res.votesYes)
          res.votesNo = parseInt(res.votesNo)
          res.statementHash = statementHash
          let challengeIndex = this.challenges.findIndex((chal) => chal.dateChallenged === res.dateChallenged)
          if (challengeIndex > -1) {
            this.challenges.splice(challengeIndex, 1, res)
          } else {
            this.challenges.push(res)
          }
          this.getChallenge(statementHash, key + 1, length).then(resolve).catch(reject)
        })
      })
    },
    voteYes (statementHash) {
      this.castVote(statementHash, true)
    },
    voteNo (statementHash) {
      this.castVote(statementHash, false)
    },
    castVote (statementHash, isYes) {
      if (this.loading) return
      this.loading = true
      if (parseInt(this.tokenBalance) < parseInt(this.amount)) {
        alert('You need to have at least ' + this.amount + ' AE tokens to do that.')
        this.loading = false
        return
      }
      let amount = this.amount
      tcr.approve(amount).then(() => {
        setTimeout(() => {
          tcr.castVote(statementHash, isYes, amount).then((res) => {
            setTimeout(this.begin, this.timeoutTime)
          }).catch((err) => {
            console.log(err)
          })
        }, this.timeoutTime)
      })
    },
    getChallengeDate (statementHash, challengeKey) {
      let challenges = this.challenges.filter(chal => chal.statementHash === statementHash).sort((a, b) => {
        return b.dateChallenged - a.dateChallenged
      })
      // console.log('challenges')
      challengeKey = parseInt(challengeKey) - 1
      if (!challenges.length) return false
      if (challengeKey > (challenges.length - 1)) return false
      return challenges[challengeKey].dateChallenged
    },
    withdraw (statementHash, challengeKey) {
      console.log(statementHash)
      let dateChallenged = this.getChallengeDate(statementHash, challengeKey)
      if (!dateChallenged) return false
      tcr.dispense(statementHash, dateChallenged).then(() => {
        setTimeout(this.begin, this.timeoutTime)
      })
    },
    initiateChallenge (statementHash) {
      if (this.loading) return
      this.loading = true
      if (parseInt(this.tokenBalance) < this.submitAmount) {
        alert('You need to have at least ' + this.submitAmount + ' AE tokens to do that.')
        this.loading = false
        return
      }
      tcr.approve(this.submitAmount).then(() => {
        setTimeout(() => {
          tcr.initiateChallenge(statementHash).then((res) => {
            setTimeout(this.begin, this.timeoutTime)
          }).catch((err) => {
            console.log(err)
          })
        }, this.timeoutTime)
      })
    },
    submit () {
      if (this.loading) return
      this.loading = true

      if (parseInt(this.tokenBalance) < this.submitAmount) {
        alert('You need to have at least ' + this.submitAmount + ' AE tokens to do that.')
        this.loading = false
        return
      }
      if (!confirm('To post a submission for the TCR you need to stake ' + this.submitAmount + ' AE tokens. If someone challenges it and succeeds then your stake will be lost and your submission will be removed. \n\nAlternatively, if someone challenegs your submission and the challenge is rejected, you will receive part of the AE stake made against you.')) {
        this.loading = false
        return
      }
      return tcr.allowance().then((allowance) => {
        if (parseInt(allowance) >= this.submitAmount) {
          return this.applyToList()
        } else {
          return tcr.approve(this.submitAmount).then(() => {
            alert('You have just given permission to the contract to move ' + this.submitAmount + ' AE tokens from your balance. The next popup will actually move those tokens into the contract to be held as your stake in the submission.')
            return this.applyToList()
          }).catch((err) => {
            console.log(err)
            this.loading = false
          })
        }
      })
    },
    applyToList () {
      return tcr.applyToList(this.statement).then((res) => {
        console.log(res)
        setTimeout(this.begin, this.timeoutTime)
        this.loading = false
      }).catch((err) => {
        console.log(err)
        this.loading = false
      })
    },
    parseInt (amount) {
      return parseInt(amount)
    }
  }
}
</script>

<style>
body {
  background-color: white;
}
#app {
  font-family: -apple-system, BlinkMacSystemFont, Helvetica, Arial, sans-serif;
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
  padding:20px 100px;
  margin-top: 60px;
}
</style>
