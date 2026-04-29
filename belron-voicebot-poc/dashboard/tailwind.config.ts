import type { Config } from "tailwindcss";

const config: Config = {
  content: [
    "./app/**/*.{js,ts,jsx,tsx,mdx}",
    "./components/**/*.{js,ts,jsx,tsx,mdx}",
    "./lib/**/*.{js,ts,jsx,tsx,mdx}",
  ],
  theme: {
    extend: {
      colors: {
        carglass: {
          red: "#E40521",
          DEFAULT: "#0B0B0B",
        },
        belron: {
          red: "#E4002B",
          "red-dark": "#B30022",
          yellow: "#FFCD00",
          "yellow-dark": "#E0B400",
          ink: "#0B0B0B",
        },
      },
    },
  },
  plugins: [],
};
export default config;
