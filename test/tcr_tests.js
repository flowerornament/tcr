var TCR = artifacts.require('TCR')
var TestToken = artifacts.require('TestToken')

contract('TCR', function (accounts) {
  let tcr;
  let testToken;

  beforeEach(async function () {
    testToken = await TestToken.new()
    tcr = await TCR.new(testToken.address)
  })

  describe('founder should ', function () {
    it('have 1000000', async function () {
      const initialBalance = await testToken.balanceOf(accounts[0])
      assert.equal(initialBalance, 1000000)
    })
  })

  describe('submitting should ', function () {
    it ('work', async function () {
      try {
        await testToken.approve(tcr.address, 5)
        await tcr.applyToList('asdf')
        const length = await tcr.getListLength()
        assert.equal(length, 1)
      } catch (error) {
        assert.fail('Should not throw error', error.message);                        
      }
    })
  })

})