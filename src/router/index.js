import Vue from 'vue'
import Router from 'vue-router'
import Submit from '@/components/Submit'

Vue.use(Router)

export default new Router({
  routes: [
    {
      path: '/',
      name: 'Submit',
      component: Submit
    }
  ]
})
