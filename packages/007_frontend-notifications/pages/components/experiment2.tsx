import { ethers } from "ethers"
import { NextComponentType } from "next"
import { FormEvent, useEffect, useState } from "react"
import Button from "./Button"

// Note: we can use chainId in each tx to know from what chain they r coming from.
// Idea: providers: { chainId: Prodider }
const Experiment2: NextComponentType = () => {
  const [transactions, setTransactions] = useState<null | any>(null)
  useEffect(() => console.log(transactions), [transactions])

  const onSubmit = async (e: FormEvent) => {
    e.preventDefault()

    const tx1 = e.target.tx1.value
    const tx2 = e.target.tx2.value

    const provider = {
      mainnet: new ethers.providers.InfuraProvider(
        "homestead",
        "cd3191fb4c5d46ea8916dbbacb904b4b"
      ),
      polygon: new ethers.providers.AlchemyProvider(
        "matic",
        "epIIrIB4Qiv8MX6viqdNdINEDBB1D9Fn"
      ),
    }

    setTransactions({
      tx1: { ...transactions?.tx1, status: "fetching" },
      tx2: { ...transactions?.tx2, status: "fetching" },
    })

    const promises = await Promise.allSettled([
      provider.mainnet
        .getTransaction(tx1)
        .then(res => ({ status: "fetched", res }))
        .catch(err => ({ status: "error", err })),
      provider.polygon
        .getTransaction(tx2)
        .then(res => ({ status: "fetched", res }))
        .catch(err => ({ status: "error", err })),
    ])

    setTransactions({ tx1: promises[0].value, tx2: promises[1].value })
  }

  return (
    <div className="border rounded border-slate-300 px-4 py-2 mt-2">
      <p>
        <strong>Experiment #2:</strong> Query 2 transactions on 2 differents
        chain
      </p>
      <form onSubmit={onSubmit}>
        <input
          placeholder="mainnet tx"
          id="tx1"
          name="tx1"
          className="border"
        />
        <input
          placeholder="polygon tx"
          id="tx2"
          name="tx2"
          className="border"
        />
        <Button type="submit">Query !</Button>

        {transactions && (
          <div className="flex mt-2">
            <Transaction {...transactions.tx1} network={"mainnet"} />
            <Transaction {...transactions.tx2} network={"polygon"} />
          </div>
        )}
      </form>
    </div>
  )
}

interface TransactionProps {
  status: "error" | "fetching" | "fetched"
  network: string
  res?: object
  err?: Error
}
const Transaction = (props: TransactionProps) => {
  const { status, res, err, network } = props

  let content
  switch (status) {
    case "error":
      content = err.toString()
      break
    case "fetching":
      content = "Fetching..."
      break
    case "fetched":
      content = <pre className="text-xs">{JSON.stringify(res, null, 2)}</pre>
      break
  }

  console.log({ status })

  return (
    <div className="grow border rounded border-slate-300 px-4 py-2 overflow-auto">
      Tx on <strong>{network}</strong>: {content}
    </div>
  )
}

export default Experiment2
