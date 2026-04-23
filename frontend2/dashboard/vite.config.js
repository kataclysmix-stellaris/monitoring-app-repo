import { defineConfig } from 'vite'
import tailwindcss from '@tailwindcss/vite'
import flowbiteReact from "flowbite-react/plugin/vite";

export default defineConfig({
  publicDir: '../../',
  plugins: [
    tailwindcss(),
    flowbiteReact()
  ],
  build: {
    rollupOptions: {
      input: {
        main: './login.html', // Points Vite to your renamed file
      },
    },
  },
})