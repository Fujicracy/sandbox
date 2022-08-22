import type { NextPage } from "next"
import Head from "next/head"
import Experiment1 from "../components/Experiment1"
import Experiment2 from "../components/Experiment2"

const Home: NextPage = () => {
  return (
    <div className="container mx-auto">
      <Head>
        <title>Create Next App</title>
        <meta name="description" content="Generated by create next app" />
        <link rel="icon" href="/favicon.ico" />
      </Head>

      <main>
        <h1 className="text-2xl py-8">Welcome to yome's playground 🎯👾</h1>

        <Experiment1 />
        <Experiment2 />
      </main>
    </div>
  )
}

export default Home