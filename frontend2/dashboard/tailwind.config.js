export default {
  content: [
    "./index.html",
    "./src/**/*.{js,ts}",
    "./node_modules/flowbite/**/*.js",
    "./node_modules/flowbite-datepicker/**/*.js",
  ],
  theme: {
    extend: {},
  },
  plugins: [
    require('flowbite/plugin')
  ]
}