import { BigNumberish, solidityPackedKeccak256, Wallet } from 'ethers'
import cardPacks from './cardPacks.json'
import { orderBy } from 'lodash'
import type { HardhatEthersSigner } from '@nomicfoundation/hardhat-ethers/signers'
import { AnimaliaCardPacks } from '../typechain-types'

export async function getOpenSignature({
  signer,
  account,
  requestConfirmations,
  openIds,
  openValues,
  contract,
}: {
  signer: Wallet| HardhatEthersSigner
  account: string
  requestConfirmations: BigNumberish
  openIds: BigNumberish[]
  openValues: BigNumberish[]
  contract: AnimaliaCardPacks
}): Promise<{
  callArgs: [
    signer: string,
    requestConfirmations: BigNumberish,
    openIds: BigNumberish[],
    openValues: BigNumberish[],
    signature: string,
  ]
  data: {
    name: string
    version: string
    verifyingContract: string
    chainId: BigNumberish
    signer: string
    account: string
    requestConfirmations: BigNumberish
    openIds: BigNumberish[]
    openValues: BigNumberish[]
    nonce: BigNumberish
    signature: string
  }
}> {
  const [name, version, verifyingContract, network, nonce] = await Promise.all([
    'Animalia Card Packs',
    '1',
    contract.getAddress(),
    signer.provider?.getNetwork(),
    contract.nonces(account),
  ])
  const chainId = network?.chainId

  if (chainId === undefined) {
    throw new Error(`Invalid chainId: ${chainId}`)
  }

  const signature = await signer.signTypedData(
    {
      name,
      version,
      chainId,
      verifyingContract,
    },
    {
      Open: [
        { type: 'address', name: 'signer' },
        { type: 'address', name: 'account' },
        { type: 'uint8', name: 'requestConfirmations' },
        { type: 'uint256[]', name: 'openIds' },
        { type: 'uint256[]', name: 'openValues' },
        { type: 'uint256', name: 'nonce' },
      ],
    },
    {
      signer: signer.address,
      account,
      requestConfirmations,
      openIds,
      openValues,
      nonce,
    }
  )

  return {
    callArgs: [
      signer.address,
      requestConfirmations,
      openIds,
      openValues,
      signature,
    ],
    data: {
      name,
      version,
      verifyingContract,
      chainId,
      signer: signer.address,
      account,
      requestConfirmations,
      openIds,
      openValues,
      nonce,
      signature,
    },
  }
}

export async function getRevealSignature({
  signer,
  mintTokenAddress,
  requestId,
  contract,
  mintIds,
  mintValues,
  transferTokenAddress,
  transferCount,
}: {
  signer: Wallet | HardhatEthersSigner
  mintTokenAddress: string
  requestId: BigNumberish
  mintIds: BigNumberish[]
  mintValues: BigNumberish[]
  transferTokenAddress: string
  transferCount: BigNumberish,
  contract: AnimaliaCardPacks
}): Promise<{
  callArgs: [
    signer: string,
    requestId: BigNumberish,
    mintTokenAddress: string,
    mintIds: BigNumberish[],
    mintValues: BigNumberish[],
    transferTokenAddress: string,
    transferCount: BigNumberish,
    signature: string,
  ]
  data: {
    name: string
    version: string
    verifyingContract: string
    chainId: BigNumberish
    signer: string
    mintTokenAddress: string
    transferTokenAddress: string
    requestId: BigNumberish
    mintIds: BigNumberish[]
    mintValues: BigNumberish[]
    transferCount: BigNumberish
  }
}> {
  const [name, version, verifyingContract, network] = await Promise.all([
    'Animalia Card Packs',
    '1',
    contract.getAddress(),
    signer.provider?.getNetwork(),
  ])
  const chainId = network?.chainId

  if (chainId === undefined) {
    throw new Error(`Invalid chainId: ${chainId}`)
  }

  const signature = await signer.signTypedData(
    {
      name,
      version,
      chainId,
      verifyingContract,
    },
    {
      Reveal: [
        { type: 'address', name: 'signer' },
        { type: 'uint256', name: 'requestId' },
        { type: 'address', name: 'mintTokenAddress' },
        { type: 'uint256[]', name: 'mintIds' },
        { type: 'uint256[]', name: 'mintValues' },
        { type: 'address', name: 'transferTokenAddress' },
        { type: 'uint256', name: 'transferCount' },
      ],
    },
    {
      signer: signer.address,
      requestId,
      mintTokenAddress,
      transferTokenAddress,
      mintIds,
      mintValues,
      transferCount,
    }
  )

  return {
    callArgs: [
      signer.address,
      requestId,
      mintTokenAddress,
      mintIds,
      mintValues,
      transferTokenAddress,
      transferCount,
      signature,
    ],
    data: {
      name,
      version,
      verifyingContract,
      chainId,
      signer: signer.address,
      requestId,
      mintTokenAddress,
      mintIds,
      mintValues,
      transferTokenAddress,
      transferCount,
    },
  }
}

export function revealCardPack(
  seed: BigNumberish,
  requestId: BigNumberish,
  walletAddress: string,
  openIds: BigNumberish[],
  openValues: BigNumberish[]
) {
  if (openIds.length !== openValues.length) {
    throw new Error(
      `Invalid length for openIds: ${openIds.length}, openValues: ${openValues.length}`
    )
  }

  let deriveIndex = 0n
  const results = []

  function deriveSeed(specificIndex?: bigint) {
    const increaseDeriveIndex = specificIndex === undefined
    const index = specificIndex ?? deriveIndex
    const result = BigInt(
      solidityPackedKeccak256(
        ['uint256', 'uint256', 'address', 'uint256'],
        [seed, requestId, walletAddress, index]
      )
    )
    if (increaseDeriveIndex) {
      deriveIndex++
    }
    return result
  }

  function getRandomBetween(min: bigint, max: bigint, randomInt?: bigint) {
    if (randomInt === undefined) {
      randomInt = deriveSeed()
    }
    return (randomInt % (max - min + 1n)) + min
  }

  for (let i = 0, ilen = openIds.length; i < ilen; i++) {
    const amount = Number(openValues[i])
    for (let j = 0; j < amount; j++) {
      const cardPackId = String(openIds[i]) as keyof typeof cardPacks
      const cardPack = cardPacks[cardPackId]

      if (cardPack === undefined) {
        throw new Error(`Invalid cardPackId: ${cardPackId}`)
      }

      const outputType = Object.keys(
        cardPack.outputType
      ) as (keyof typeof cardPack.outputType)[]
      const cardPullResult = []
      let arcanaCount = 0

      if (cardPack.arcanaPull.probability > 0) {
        const hit = getRandomBetween(0n, 100_00n) <= cardPack.arcanaPull.probability
        if (hit) {
          arcanaCount++
        }
      }

      for (const specialPull of cardPack.specialPulls) {
        if (specialPull.cards.length <= 0) {
          throw new Error(
            `Insufficient cards for specialPull: ${specialPull.cards.length}`
          )
        }

        const skipWhenRarityCount = Object.keys(
          specialPull.skipWhenRarityCount
        ) as (keyof typeof specialPull.skipWhenRarityCount)[]
        let skip = false
        for (const rarity of skipWhenRarityCount) {
          if (typeof specialPull.skipWhenRarityCount[rarity] !== 'number') {
            continue
          }
          if (
            cardPullResult
              .filter((c) => c.info.rarity === rarity).length >=
            specialPull.skipWhenRarityCount[rarity]
          ) {
            skip = true
            break
          }
          if (rarity === 'Arcana' && arcanaCount >= specialPull.skipWhenRarityCount[rarity]) {
            skip = true
            break
          }
        }
        if (skip) {
          continue
        }
        const hit = getRandomBetween(0n, 100_00n) <= specialPull.probability
        if (!hit) {
          continue
        }

        let cards = specialPull.cards
        for (const type of outputType) {
          if (
            cardPullResult.filter((c) => c.info.type === type).length >=
            cardPack.outputType[type]
          ) {
            cards = cards.filter((c) => c.info.type !== type)
          }
        }
        if (cards.length <= 0) {
          throw new Error(
            `Insufficient cards for specialPull after filter: ${cards.length}`
          )
        }
        const card =
          cards[Number(getRandomBetween(0n, BigInt(cards.length - 1)))]
        if (card) {
          cardPullResult.push(card)
        }
      }

      const pullTypes = Object.keys(
        cardPack.cardPulls
      ) as (keyof typeof cardPack.cardPulls)[]

      for (const type of pullTypes) {
        const cardPulls = cardPack.cardPulls[type]
        const outputType = cardPack.outputType[type]
        if (outputType === undefined) {
          throw new Error(
            `Invalid outputType: ${Object.keys(cardPack.outputType).join(
              ', '
            )}, type: ${type}`
          )
        }
        for (let k = 0; k < outputType; k++) {
          for (let l = 0, llen = cardPulls.length; l < llen; l++) {
            const cardPull = cardPulls[l]
            if (
              cardPullResult.filter((c) => c.info.type === type).length >=
              outputType
            ) {
              break
            }
            const hit =
              getRandomBetween(0n, 100_00n) <= BigInt(cardPull.probability)
            if (!hit) {
              continue
            }

            const cards = cardPull.cards
            if (cards.length <= 0) {
              throw new Error(
                `Insufficient cards for cardPull: ${cards.length}`
              )
            }
            const card =
              cards[Number(getRandomBetween(0n, BigInt(cards.length - 1)))]
            if (card) {
              cardPullResult.push(card)
            }
            break
          }
        }
      }

      const finalPullResult = cardPullResult

      if (
        finalPullResult.length < 6 ||
        finalPullResult.filter((c) => c.info.type === 'Weapons').length <
        cardPack.outputType.Weapons ||
        finalPullResult.filter((c) => c.info.type === 'Spells').length <
        cardPack.outputType.Spells ||
        finalPullResult.filter((c) => c.info.type === 'Critters').length <
        cardPack.outputType.Critters
      ) {
        console.log()
        console.log(cardPack.name)
        console.log(finalPullResult)
        throw new Error('Invalid finalPullResult')
      }

      const cards = orderBy(finalPullResult, ['name'], ['asc'])
      const cardEntries = cards
        .filter((card) => card.info.rarity !== 'Arcana')
        .reduce(
          (cardEntries, card) => {
            cardEntries[card.info.tokenId] = cardEntries[card.info.tokenId] ?? 0
            cardEntries[card.info.tokenId]++
            return cardEntries
          },
          {} as {
            [tokenId: string]: number
          }
        )

      results.push({
        cardPack,
        cards,
        mintIds: Object.keys(cardEntries),
        mintValues: Object.values(cardEntries),
        arcanaCount,
      })
    }
  }

  const entries = results.reduce(
    (entries, result) => {
      for (let i = 0, ilen = result.mintIds.length; i < ilen; i++) {
        const mintId = result.mintIds[i]
        const mintValue = result.mintValues[i]
        entries[mintId] = entries[mintId] ?? 0
        entries[mintId] += mintValue
      }
      return entries
    },
    {} as {
      [tokenId: string]: number
    }
  )

  const arcanaCount = results.reduce((total, result) => { return total + result.arcanaCount }, 0)

  return {
    results,
    mintIds: Object.keys(entries),
    mintValues: Object.values(entries),
    arcanaCount
  }
}
