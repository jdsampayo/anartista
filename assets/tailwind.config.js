// See the Tailwind configuration guide for advanced usage
// https://tailwindcss.com/docs/configuration

const plugin = require("tailwindcss/plugin")
const fs = require("fs")
const path = require("path")


// fondo: #a23a61
// subfondo / acento: #688f96
// primario: #e26575
// secundario: #f0b5bd
// terciario / ligero: #d4c9c7

module.exports = {
  content: [
    "./js/**/*.js",
    "../lib/anartista_web.ex",
    "../lib/anartista_web/**/*.*ex"
  ],
  theme: {
    extend: {
      colors: {
        'primary': '#9ea531', // verde
        'secondary': '#B5DDD1', // menta agua
        'light': '#dcdcd7',
        'dark': '#594d3d', // gris oscuro
        'accent': '#121212',
        'cement': '#ded9ca',
        'white': '#E8E6E1',
        'green': '#9ea531'
      },
      fontFamily: {
        'sans': ['Open Sans', 'Helvetica Neue', 'Helvetica', 'Arial', 'Segoe UI', 'Roboto', 'Noto Sans', 'sans-serif'],
        'serif': ['Georgia', 'Times New Roman', 'Cambria', 'Palatino Linotype', 'Book Antiqua', 'Palatino', 'serif'],
        'mosaic': ["ClassicMosaic"],
      },
    },
  },
  plugins: [
    require("@tailwindcss/forms"),
    // Allows prefixing tailwind classes with LiveView classes to add rules
    // only when LiveView classes are applied, for example:
    //
    //     <div class="phx-click-loading:animate-ping">
    //
    plugin(({ addVariant }) => addVariant("phx-click-loading", [".phx-click-loading&", ".phx-click-loading &"])),
    plugin(({ addVariant }) => addVariant("phx-submit-loading", [".phx-submit-loading&", ".phx-submit-loading &"])),
    plugin(({ addVariant }) => addVariant("phx-change-loading", [".phx-change-loading&", ".phx-change-loading &"])),

    // Embeds Heroicons (https://heroicons.com) into your app.css bundle
    // See your `CoreComponents.icon/1` for more information.
    //
    plugin(function ({ matchComponents, theme }) {
      let iconsDir = path.join(__dirname, "../deps/heroicons/optimized")
      let values = {}
      let icons = [
        ["", "/24/outline"],
        ["-solid", "/24/solid"],
        ["-mini", "/20/solid"],
        ["-micro", "/16/solid"]
      ]
      icons.forEach(([suffix, dir]) => {
        fs.readdirSync(path.join(iconsDir, dir)).forEach(file => {
          let name = path.basename(file, ".svg") + suffix
          values[name] = { name, fullPath: path.join(iconsDir, dir, file) }
        })
      })
      matchComponents({
        "hero": ({ name, fullPath }) => {
          let content = fs.readFileSync(fullPath).toString().replace(/\r?\n|\r/g, "")
          let size = theme("spacing.6")
          if (name.endsWith("-mini")) {
            size = theme("spacing.5")
          } else if (name.endsWith("-micro")) {
            size = theme("spacing.4")
          }
          return {
            [`--hero-${name}`]: `url('data:image/svg+xml;utf8,${content}')`,
            "-webkit-mask": `var(--hero-${name})`,
            "mask": `var(--hero-${name})`,
            "mask-repeat": "no-repeat",
            "background-color": "currentColor",
            "vertical-align": "middle",
            "display": "inline-block",
            "width": size,
            "height": size
          }
        }
      }, { values })
    })
  ]
}
