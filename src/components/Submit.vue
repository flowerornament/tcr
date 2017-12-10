<template>
  <div>
    <form @submit.prevent="submit">
      <input v-model="statement">
    </form>
  </div>
</template>

<script>

import TCR from '../../dapp-scratch-wrapper/TCR'
const tcr = new TCR()
export default {

  name: 'Submit',

  data () {
    return {
      statement: ''
    }
  },
  methods: {
    submit () {
      tcr.approve(TCR.account, 5).then(() => {
        setTimeout(() => {
          tcr.applyToList(this.statement).then((res) => {
            console.log(res)
          }).catch((err) => {
            console.log(err)
          })
        }, 3000)
      })
    }
  }
}
</script>

<style lang="css" scoped>
</style>
          