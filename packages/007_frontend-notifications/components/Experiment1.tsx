import { useActor, useSelector } from "@xstate/react"
import { NextComponentType } from "next"
import { useContext } from "react"
import { GlobalStateContext } from "../pages/_app"
import Button from "./Button"
import { AuthStateMachine } from "./machines/authMachine"

const selectUser = (machine: AuthStateMachine) => machine.context.user
const selectError = (machine: AuthStateMachine) => machine.context.error

const Experiment1: NextComponentType = () => {
  const { authService } = useContext(GlobalStateContext)
  const [state, send] = useActor(authService)
  const error = useSelector(authService, selectError)
  const user = useSelector(authService, selectUser)

  return (
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
  )
}

export default Experiment1
