<template>
  <div id="app">
    <!-- <router-view/> -->
    <div style="position:absolute" v-if="loading">Loading...</div>
    <div style="margin-top:2em;">
      <div v-text="balance + ' ETH'"></div>
      <div v-text="tokenBalance + ' AE'"></div>
    </div>
    <form @submit.prevent="submit">
      <input class="submit" placeholder="Ask a question" v-model="statement">
    </form>
    <div class="entry" v-for="entry in whitelist">
      <h1 class="statement">{{entry.statement}}</h1>
      <h2>{{status(entry.statementHash)}}</h2>

      <!-- <div>statementHash: {{entry.statementHash}}</div>
      <div>lister: {{entry.lister}}</div>
      <div>dateAdded: {{entry.dateAdded}}</div>
      <div>challengeKeysLength: {{entry.challengeKeysLength}}</div>
      <div>exists: {{entry.exists}}</div> -->

      <button class="challenge" @click="initiateChallenge(entry.statementHash)">Challenge</button>
      <div class="vote" v-if="status(entry.statementHash) === 'Challenged'">
          <input v-model="amount"></input>
          <button @click="voteYes(entry.statementHash)">KEEP</button>
          <button @click="voteNo(entry.statementHash)">REMOVE</button>
      </div>
      <div v-if="entry.challengeKeysLength > 0 && status(entry.statementHash) === 'Yes' || status(entry.statementHash) === 'No'">
          <div v-for="i in parseInt(entry.challengeKeysLength)" :key="getChallengeDate(entry.statementHash, i)"><button @click="withdraw(entry.statementHash, i)">Dispense Winnings from Challenge Number {{i}}</button></div>
      </div>
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
          // if it's fresh return Challenged
          let challenges = this.challenges.filter((chal) => chal.statementHash === entry.statementHash)
          .sort((a, b) => (b.dateChallenged - a.dateChallenged))
          if (challenges.length) {
            if (challenges[0].dateChallenged < entry.dateAdded) {
              return 'Maybe'
            } else if (challenges[0].dateChallenged + this.challengePeriod > now) {
              return 'Challenged'
            } else {
              return 'Maybe' // shouldn't be reachable but is
            }
          } else {
            return 'Maybe'
          }
        } else {
          return 'Maybe'
        }
      } else {
        // wait period is over
        // options are Challenged, Yes or no
        if (parseInt(entry.challengeKeysLength) > 0) {
          // theres a challenge
          // if it's stale, then it's not Challenged, and return Yes
          // if it's fresh, see if it's over
          // if not over, return Challenged
          // if it is over return Yes or no
          let challenges = this.challenges.filter((chal) => chal.statementHash === entry.statementHash)
          .sort((a, b) => (b.dateChallenged - a.dateChallenged))
          // if (entry.statement === 'third') console.log(challenges.map(chal => { return { votesYes: chal.votesYes, votesNo: chal.votesNo } }))
          if (challenges.length) {
            // stale, not actually Challenged
            if (challenges[0].dateChallenged < entry.dateAdded) {
              return 'Yes'
            } else if (challenges[0].dateChallenged + this.challengePeriod > now) {
              return 'Challenged'
            } else if (challenges[0].votesNo > challenges[0].votesYes) {
              return 'No'
            } else {
              return 'Yes'
            }
          } else {
            return 'Yes'
          }
        } else {
          return 'Yes'
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
        return tcr.getChallenge(key, statementHash).then((res) => {
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
          return this.getChallenge(statementHash, key + 1, length).then(resolve).catch(reject)
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
      let amount = parseInt(this.amount)
      if (parseInt(this.tokenBalance) < parseInt(amount)) {
        alert('You need to have at least ' + this.amount + ' AE tokens to do that.')
        this.loading = false
        return
      }

      if (!confirm('To make this vote you must stake your ' + this.amount + ' AE tokens from your balance. These will be taken from you if you fail to vote for the winning side.')) {
        this.loading = false
      } else {
        return tcr.approve(this.amount).then(() => {
          alert('You have just given permission to the contract to move ' + this.amount + ' AE tokens from your balance. The next popup will actually move those tokens into the contract to be held as your stake in the vote.')
          return tcr.castVote(statementHash, isYes, this.amount).then((res) => {
            setTimeout(this.begin, this.timeoutTime)
          }).catch((err) => {
            console.log(err)
          })
        }).catch((err) => {
          console.log(err)
          this.loading = false
        })
      }
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
      if (this.loading) return
      this.loading = true
      let dateChallenged = this.getChallengeDate(statementHash, challengeKey)
      if (!dateChallenged) return false
      return tcr.dispense(statementHash, dateChallenged).then(() => {
        this.loading = false
        setTimeout(this.begin, this.timeoutTime)
      }).catch((err) => {
        console.log(err)
        this.loading = false
      })
    },

    initiateChallenge (statementHash) {
      if (this.loading) return
      this.loading = true
      if ((parseInt(this.tokenBalance) * 1000000000000000000) < this.submitAmount) {
        alert('You need to have at least ' + this.submitAmount + ' AE tokens to do that.')
        this.loading = false
        return
      }
      if (!confirm('To make a challenge a submission you must stake ' + this.submitAmount + ' AE tokens from your balance. These will be taken from you if you fail to secure the votes needed to successfully challenege the submission.')) {
        this.loading = false
      } else {
        return tcr.approve(this.submitAmount).then(() => {
          alert('You have just given permission to the contract to move ' + this.submitAmount + ' AE tokens from your balance. The next popup will actually move those tokens into the contract to be held as your stake in the challenge.')
          return tcr.initiateChallenge(statementHash).then((res) => {
            this.loading = false
            setTimeout(this.begin, this.timeoutTime)
          }).catch((err) => {
            this.loading = false
            console.log(err)
          })
        }).catch((err) => {
          console.log(err)
          this.loading = false
        })
      }
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
      } else {
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
      }
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
  font-family: -apple-system, BlinkMacSystemFont, Arial, sans-serif;
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
  padding:20px 100px;
  margin-top: 60px;
}
.entry {
  margin-bottom: 4em;
}
.statement:first-letter {
  text-transform: capitalize;
}
button {
  font-size: 13px;
}
.submit {
  color: black;
  font-size: 32px;
  font-weight: bold;
  height: 1.5em;
  width: 30em;
  padding-left: 0.2em;
  margin-bottom: 1.5em;
}
.challenge {
  margin-bottom: 1em;
}
.vote {
  margin-bottom: 1em;
}
</style>
