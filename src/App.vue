<template>
  <div id="app">
    <!-- <router-view/> -->
    <form @submit.prevent="submit">
      <input class="submit" placeholder="Got a question?" v-model="statement">
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
      <div class="vote" v-if="status(entry.statementHash) === 'challenged'">
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
import TCR from '../dapp-scratch-wrapper/TCR/index.js'
let tcr = new TCR()
tcr.helloWorld()

global.tcr = tcr // CL

export default {
  name: 'app',

  data () {
    return {
      whitelist: [],
      challenges: [],
      statement: '',
      amount: 0,
      waitPeriod: (60 * 5),
      timeoutTime: 2000,
      // waitPeriod: (60 * 60) * 48,
      // challengePeriod: (60 * 60) * 24
      challengePeriod: (60 * 2)
    }
  },

  mounted () {
    setTimeout(this.begin, 3000)
  },

  methods: {
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
        tcr.getListLength().then((length) => {
          this.getEntry(0, length)
        })
      }
    },

    getEntry (key = 0, length) {
      if (key < length) {
        return tcr.getEntry(key).then((res) => {
          res.dateAdded = parseInt(res.dateAdded)
          this.whitelist.unshift(res)
          if (res.challengeKeysLength > 0) {
            this.getChallenge(res.statementHash, 0, res.challengeKeysLength).then(() => {
              this.getEntry(key + 1, length)
            })
          } else {
            this.getEntry(key + 1, length)
          }
        })
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
      let dateChallenged = this.getChallengeDate(statementHash, challengeKey)
      if (!dateChallenged) return false
      tcr.dispense(tcr.address, dateChallenged).then(() => {
        setTimeout(this.begin, this.timeoutTime)
      })
    },

    initiateChallenge (statementHash) {
      tcr.approve(5).then(() => {
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
      console.log(tcr.address)
      tcr.approve(5).then(() => {
        setTimeout(() => {
          tcr.applyToList(this.statement).then((res) => {
            console.log(res)
            setTimeout(this.begin, this.timeoutTime)
          }).catch((err) => {
            console.log(err)
          })
        }, this.timeoutTime)
      }).catch((err) => {
        console.log(err)
      })
    },

    parseInt (amount) {
      return parseInt(amount)
    }
  }
}
</script>

<style>
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
