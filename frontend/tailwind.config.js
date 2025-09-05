/** @type {import('tailwindcss').Config} */
export default {
  darkMode: 'class',
  content: [
    './index.html',
    './src/**/*.{ts,tsx}'
  ],
  theme: {
    extend: {
      colors: {
        brand: {
          500: '#ff9933', // saffron
          600: '#e6801a',
          700: '#cc7000'
        },
        indiaGreen: '#138808',
        govBlue: '#0b1f3a',
      },
      backdropBlur: {
        xs: '2px'
      }
    },
  },
  plugins: [],
}

