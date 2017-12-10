<template>
  <div id="app">
    <img src="./assets/logo.png">
    <router-view/>
  </div>
</template>

<script>
import TCR from '../dapp-scratch-wrapper/TCR/index.js'
let tCR = new TCR()
tCR.helloWorld()

global.tcr = tCR // CL

export default {
  name: 'app',
  data () {
    return {
      whitelist: []
    }
  },
  mounted () {
    setTimeout(this.begin, 3000)
  },
  methods: {
    begin () {
      tCR.getListLength().then((length) => {
        this.getEntry(0, length)
      })
    },
    getEntry (key = 0, length) {
      if (key < length) {
        console.log('get entry?')
        return tCR.getEntry(key)
      }
    }
  }
}
</script>

<style>
#app {
  font-family: 'Avenir', Helvetica, Arial, sans-serif;
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
  text-align: center;
  color: #2c3e50;
  margin-top: 60px;
}
</style>
