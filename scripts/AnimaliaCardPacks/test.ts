import { config, ethers } from 'hardhat'
import cardPacks from '../../utils/cardPacks.json'
import { randomBytes, randomInt } from 'crypto'
import { add } from 'date-fns'
import { getPurchaseSignature } from '../../utils/utils.cardPackSales'
import { getAnimPriceInUSD } from '../../utils/animPrice'
import { getOpenSignature, getRevealSignature, revealCardPack } from '../../utils/utils.cardPacks'
// import { HardhatNetworkHDAccountsConfig } from 'hardhat/types'

type Card = {
  name: string
  description: string
  image: string
  attributes: {
    trait_type: string
    value: any
  }[]
  info: {
    tokenId: string
  }
}

const cards = Object.values(cardPacks).reduce((cards, cardPack) => {
  for (const pull of cardPack.specialPulls) {
    for (const card of pull.cards) {
      if (!cards.some(c => c.info.tokenId === card.info.tokenId)) {
        cards.push(card)
      }
    }
  }

  for (const pull of cardPack.cardPulls.Critters) {
    for (const card of pull.cards) {
      if (!cards.some(c => c.info.tokenId === card.info.tokenId)) {
        cards.push(card)
      }
    }
  }

  for (const pull of cardPack.cardPulls.Spells) {
    for (const card of pull.cards) {
      if (!cards.some(c => c.info.tokenId === card.info.tokenId)) {
        cards.push(card)
      }
    }
  }

  for (const pull of cardPack.cardPulls.Weapons) {
    for (const card of pull.cards) {
      if (!cards.some(c => c.info.tokenId === card.info.tokenId)) {
        cards.push(card)
      }
    }
  }
  return cards
}, [] as Card[])

{
  (async function () {
    // const accounts = config.networks.hardhat.accounts as HardhatNetworkHDAccountsConfig
    const signers = await ethers.getSigners()
    const owner = signers[0]
    const oracle = signers[0]
    const marketplace = signers[0]
    const provider = owner.provider
    if (!provider) {
      throw new Error('Provider not ready.')
    }
    const { chainId } = await provider.getNetwork()
    const isLocalhost = chainId === 31337n

    console.log('chainId', chainId)
    console.log('owner.address', owner.address)
    console.log('balanceOf owner.address', ethers.formatEther(await provider.getBalance(owner.address)))

    if (!isLocalhost) {
      throw new Error('Not localhost')
    }

    const arcanaSC = await (
      await ethers.getContractFactory('AnimaliaGenesisArcana')
    ).connect(owner).deploy(
      'Animalia Genesis Arcana',
      'ANIM GA',
      '',
      2000,
      1,
      owner.address,
      500
    )
    console.log('arcanaSC deployed', await arcanaSC.getAddress())

    const randomProviderSC = await (
      await ethers.getContractFactory('RandomProvider')
    ).connect(owner).deploy()
    console.log('randomProviderSC deployed', await randomProviderSC.getAddress())

    // set random oracle role
    await randomProviderSC.connect(owner).grantRole(await randomProviderSC.ORACLE_ROLE(), oracle.address)

    const cardPacksSC = await (
      await ethers.getContractFactory('AnimaliaCardPacks')
    ).connect(owner).deploy(owner.address, 500, "", await randomProviderSC.getAddress())
    console.log('cardPacksSC deployed', await cardPacksSC.getAddress())

    const cardsSC = await (
      await ethers.getContractFactory('AnimaliaCards')
    ).connect(owner).deploy(owner.address, 500, "")
    console.log('cardsSC deployed', await cardsSC.getAddress())

    // allow card packs to mint cards
    await cardsSC.connect(owner).grantRole(await cardsSC.MINTER_ROLE(), await cardPacksSC.getAddress())

    const salesSC = await (
      await ethers.getContractFactory('AnimaliaCardPackSales')
    ).connect(owner).deploy(signers[2].address, await cardPacksSC.getAddress())
    console.log('salesSC deployed', await salesSC.getAddress())

    // set marketplace role
    await salesSC.connect(owner).grantRole(await salesSC.MARKETPLACE_ROLE(), marketplace.address)

    // allow sales to mint packs
    await cardPacksSC.connect(owner).grantRole(await cardPacksSC.MINTER_ROLE(), await salesSC.getAddress())

    // grant opener role
    await cardPacksSC.connect(owner).grantRole(await cardPacksSC.OPENER_ROLE(), marketplace)

    // grant revealer role
    await cardPacksSC.connect(owner).grantRole(await cardPacksSC.REVEALER_ROLE(), marketplace)

    // prepare 100 arcana
    await arcanaSC.connect(owner)['mint(address,uint8)'](await cardPacksSC.getAddress(), 100)

    // set active sales
    const _cardPackSales = [{
      id: 1,
      saleCurrency: ethers.ZeroAddress,
      salePriceInUSD: 20_000000n,
      unset: false,
    }, {
      id: 2,
      saleCurrency: ethers.ZeroAddress,
      salePriceInUSD: 20_000000n,
      unset: false,
    }, {
      id: 3,
      saleCurrency: ethers.ZeroAddress,
      salePriceInUSD: 20_000000n,
      unset: false,
    }, {
      id: 4,
      saleCurrency: ethers.ZeroAddress,
      salePriceInUSD: 35_000000n,
      unset: false,
    }]
    await salesSC.connect(owner).setCardPackSales(
      _cardPackSales.map(cps => cps.id),
      _cardPackSales.map(cps => cps.saleCurrency),
      _cardPackSales.map(cps => cps.salePriceInUSD),
      _cardPackSales.map(cps => cps.unset)
    )

    const cardPackIds = _cardPackSales.map(cps => cps.id)

    for (const signer of signers) {
      // console.log()
      // console.log('balanceOf', signer.address, await cardPacksSC.balanceOfBatch(cardPackIds.map(_ => signer.address), cardPackIds))

      const amounts = cardPackIds.map(() => BigInt(randomInt(0, 11)))
      const salePrices = _cardPackSales.map(cps => getAnimPriceInUSD() * cps.salePriceInUSD / 1_000000n)
      const deadline = Math.floor(add(new Date(), { seconds: 60 }).getTime() / 1000)

      // console.log('salePrices', salePrices)

      const { data: { signature } } = await getPurchaseSignature({
        signer: marketplace,
        buyer: signer.address,
        cardPackIds,
        amounts,
        contract: salesSC,
        deadline,
        salePrices,
      })

      // let value = 0n
      // for (let i = 0; i < amounts.length; i++) {
      //   value += amounts[i] * salePrices[i]
      // }
      const value = amounts.reduce((value, amount, i) => value + (amount * salePrices[i]), 0n)
      await salesSC.connect(signer).purchase(marketplace.address, cardPackIds, amounts, salePrices, deadline, signature, {
        value,
      })

      // console.log('balanceOf', signer.address, await cardPacksSC.balanceOfBatch(cardPackIds.map(_ => signer.address), cardPackIds))
    }

    for (const signer of signers) {
      console.log()
      console.log('balanceOf', signer.address, await cardPacksSC.balanceOfBatch(cardPackIds.map(_ => signer.address), cardPackIds))
      const balances = await cardPacksSC.balanceOfBatch(cardPackIds.map(_ => signer.address), cardPackIds)

      const open = await getOpenSignature({
        signer: marketplace,
        account: signer.address,
        contract: cardPacksSC,
        openIds: cardPackIds,
        openValues: balances.map(b => b),
        requestConfirmations: 1,
      })

      // console.log(await cardsSC.balanceOfBatch(cards.map(_ => signer.address), cards.map(c => c.info.tokenId)))

      // console.log(data.signer, data.requestConfirmations, data.openIds, data.openValues, data.signature)
      await cardPacksSC.connect(signer).open(...open.callArgs)

      console.log('balanceOf', signer.address, await cardPacksSC.balanceOfBatch(cardPackIds.map(_ => signer.address), cardPackIds))

      const requests = await cardPacksSC.getRequestsByAccount(signer.address, true)

      const request = requests[0]
      // const request = requests.find(
      //   (r) => Number(r.requestId) === Number(requestId.hex)
      // )

      if (!request) {
        continue
      }

      console.log('pending requests', await randomProviderSC.getPendingRequestCount())
      // secure oracle to generate random
      await randomProviderSC.connect(oracle).fulfillRandom(`0x${randomBytes(32).toString('hex')}`, 10)
      console.log('pending requests', await randomProviderSC.getPendingRequestCount())

      const { mintIds, mintValues, arcanaCount } = revealCardPack(
        request.random,
        request.requestId,
        request.account,
        request.openIds,
        request.openValues,
      )

      const reveal = await getRevealSignature({
        signer: marketplace,
        contract: cardPacksSC,
        requestId: request.requestId,
        mintIds,
        mintValues,
        mintTokenAddress: await cardsSC.getAddress(),
        transferTokenAddress: await arcanaSC.getAddress(),
        transferCount: arcanaCount,
      })

      console.log(await cardsSC.balanceOfBatch(cards.map(_ => signer.address), cards.map(c => c.info.tokenId)))

      await cardPacksSC.connect(signer).reveal(...reveal.callArgs)

      console.log(await cardsSC.balanceOfBatch(cards.map(_ => signer.address), cards.map(c => c.info.tokenId)))

      break
    }
  })()
}