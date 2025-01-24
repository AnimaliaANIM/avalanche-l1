import { BigNumberish, Wallet } from 'ethers'
import type { HardhatEthersSigner } from '@nomicfoundation/hardhat-ethers/signers'
import { AnimaliaCardPackSales } from '../typechain-types'

export async function getPurchaseSignature({
  signer,
  buyer,
  cardPackIds,
  amounts,
  salePrices,
  deadline,
  contract
}: {
  signer: Wallet | HardhatEthersSigner
  buyer: string
  cardPackIds: BigNumberish[]
  amounts: BigNumberish[]
  salePrices: BigNumberish[]
  deadline: BigNumberish
  contract: AnimaliaCardPackSales
}): Promise<{
  callArgs: [
    signer: string,
    cardPackIds: BigNumberish[],
    amounts: BigNumberish[],
    salePrices: BigNumberish[],
    deadline: BigNumberish,
    signature: string,
  ]
  data: {
    name: string
    version: string
    verifyingContract: string
    chainId: bigint
    signer: string
    cardPackIds: BigNumberish[]
    amounts: BigNumberish[]
    salePrices: BigNumberish[]
    deadline: BigNumberish
    nonce: bigint
    signature: string
  }
}> {
  const [
    name,
    version,
    verifyingContract,
    network,
    nonce,
  ] = await Promise.all([
    'Animalia Card Pack Sales',
    '1',
    contract.getAddress(),
    signer.provider?.getNetwork(),
    contract.nonces(buyer),
  ])
  const chainId = network?.chainId

  if (chainId === undefined) {
    throw new Error(`Invalid chainId: ${chainId}`)
  }

  const signature = await signer.signTypedData({
    name,
    version,
    chainId,
    verifyingContract,
  }, {
    Purchase: [
      { type: 'address', name: 'buyer' },
      { type: 'uint256[]', name: 'cardPackIds' },
      { type: 'uint256[]', name: 'amounts' },
      { type: 'uint256[]', name: 'salePrices' },
      { type: 'uint256', name: 'nonce' },
      { type: 'uint256', name: 'deadline' },
    ],
  }, {
    buyer,
    cardPackIds,
    amounts,
    salePrices,
    nonce,
    deadline,
  })

  return {
    callArgs: [
      signer.address,
      cardPackIds,
      amounts,
      salePrices,
      deadline,
      signature,
    ],
    data: {
      name,
      version,
      verifyingContract,
      chainId,
      signer: signer.address,
      cardPackIds,
      amounts,
      salePrices,
      deadline,
      nonce,
      signature,
    },
  }
}
