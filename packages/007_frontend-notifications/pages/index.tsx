import { useActor, useSelector } from "@xstate/react"
import type { NextPage } from "next"
import Head from "next/head"
import { useContext } from "react"
import Button from "./components/Button"
import Experiment2 from "./components/experiment2"
import { AuthStateMachine } from "./machines/authMachine"
import { GlobalStateContext } from "./_app"

const selectUser = (machine: AuthStateMachine) => machine.context.user
const selectError = (machine: AuthStateMachine) => machine.context.error

const Home: NextPage = () => {
  const { authService } = useContext(GlobalStateContext)
  const [state, send] = useActor(authService)
  const error = useSelector(authService, selectError)
  const user = useSelector(authService, selectUser)

  return (
    <div className="container mx-auto">
      <Head>
        <title>Create Next App</title>
        <meta name="description" content="Generated by create next app" />
        <link rel="icon" href="/favicon.ico" />
      </Head>

      <main>
        <h1 className="text-2xl py-8">Welcome to yome's playground 🎯👾</h1>

        <div className="border rounded border-slate-300 px-4 py-2">
          <p>
            <strong>Experiment #1:</strong> Login with blocknative & xstate
          </p>
          <p>
            Current state of authService <code>{state.value}</code>
          </p>
          {state.context.user ? (
            <Button onClick={() => send("LOGOUT")}>Log out</Button>
          ) : (
            <Button onClick={() => send("INITIALIZE")}>Login</Button>
          )}
          {state.context.error && <p>Error: {error}</p>}
          {state.context.user && (
            <p>
              User: <code>{user.address}</code>
            </p>
          )}
        </div>

        <Experiment2 />
      </main>
    </div>
  )
}

export default Home
