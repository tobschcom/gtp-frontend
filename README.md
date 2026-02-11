# Welcome to the growthepie 📏🥧 Frontend!

[growthepie](https://growthepie.xyz/) aims to enhance transparency and understanding of the Ethereum Layer 2 ecosystem by providing comprehensive, curated data, blockspace analysis and educational resources to users, developers and investors.

The growthepie frontend provides an engaging user interface, displaying curated data and analysis sourced from our robust [backend](https://github.com/growthepie/gtp).

<p align="center">
  <img src="https://github.com/growthepie/.github/assets/90760534/ca2ca39f-657b-4f79-8550-242b4ee9c4ec" alt="Sublime's custom image"/>
</p>

## gtp - Frontend Repository

The [`gtp-frontend`](https://github.com/growthepie/gtp-frontend) repository is built with Next.js, leveraging modern web technologies to ensure a responsive and interactive experience for our users.

### Features

- Built with [Next.js](https://nextjs.org/)
- Styled with [Tailwind CSS](https://tailwindcss.com/)
- Data sourced from growthepie's [API](https://github.com/growthepie/gtp)
- Data visualizations using [Highcharts](https://highcharts.com)
- Deployed on [Vercel](https://vercel.com/)

## Get Involved

- **Contribute**: Fork our repo, make your changes, and submit a pull request.
- **Join Our Community**: For discussions and collaboration, join us on [Discord](https://discord.gg/pKzYwm7h).

## iOS App (Capacitor)

This repository now includes a Capacitor baseline so we can ship a native iOS shell
that loads the live growthepie web app and stays in sync with website updates.

### Setup

Prerequisites: macOS with full Xcode installed (not only Command Line Tools) and CocoaPods available.

1. Install dependencies:
   ```bash
   yarn install
   ```
2. Create the iOS project once:
   ```bash
   yarn cap:add:ios
   ```
3. Sync Capacitor config/plugins:
   ```bash
   yarn cap:sync:ios
   ```
4. Open Xcode:
   ```bash
   yarn cap:open:ios
   ```

### Mobile URL

- Default iOS dev URL: `http://localhost:3000` (via `yarn cap:sync:ios`)
- Production sync helper:
  ```bash
  yarn cap:sync:ios:prod
  ```
- Override explicitly with:
  ```bash
  CAPACITOR_SERVER_URL=https://dev.growthepie.com yarn cap:sync:ios
  ```

Your involvement is vital to growthepie and our mission to enhance transparency in the Ethereum Layer 2 ecosystem.

## License

The growthepie frontend is licensed under the [MIT License](LICENSE).
