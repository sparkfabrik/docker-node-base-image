// Force dynamic rendering so every request exercises the runtime server
// (and its cache directory) instead of serving a build-time static page.
export const dynamic = "force-dynamic";

export default function Home() {
  return <main>Hello from Next.js on the SparkFabrik Node.js base image</main>;
}
