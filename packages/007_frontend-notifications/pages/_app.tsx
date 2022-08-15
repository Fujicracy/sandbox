import "../styles/globals.css"
import type { AppProps } from "next/app"

import { useInterpret } from "@xstate/react"
import { authMachine, AuthStateMachine } from "./machines/authMachine"
import { createContext } from "react"
import { inspect } from "@xstate/inspect"

if (typeof window !== "undefined") {
  inspect({
    // options
    // url: 'https://stately.ai/viz?inspect', // (default)
    iframe: false, // open in new window
  })
}

// TODO: Typing
interface GlobalStateContext {
  authService: AuthStateMachine
}
export const GlobalStateContext = createContext({} as GlobalStateContext)

function MyApp({ Component, pageProps }: AppProps) {
  const authService = useInterpret(authMachine, {
    devTools: process.env.NODE_ENV === "development",
  })

  return (
    <GlobalStateContext.Provider value={{ authService }}>
      <Component {...pageProps} />
    </GlobalStateContext.Provider>
  )
}

export default MyApp
