import pluginJs from "@eslint/js"
import prettierConfig from "eslint-config-prettier/flat"
import importPlugin from "eslint-plugin-import"
import pluginReact from "eslint-plugin-react"
import reactHooks from "eslint-plugin-react-hooks"
import globals from "globals"
import tseslint from "typescript-eslint"

/** @type {import('eslint').Linter.Config[]} */
export default [
  { files: ["app/javascript/**/*.{js,mjs,cjs,ts,jsx,tsx}"] },
  { ignores: ["app/javascript/components/ui/**", "app/javascript/routes/**"] },
  {
    settings: {
      react: {
        version: "detect",
      },
    },
    languageOptions: {
      globals: { ...globals.browser, ...globals.node },
      parserOptions: {
        projectService: true,
        tsconfigRootDir: import.meta.dirname,
      },
    },
  },
  pluginJs.configs.recommended,
  reactHooks.configs.flat.recommended,
  ...tseslint.configs.stylisticTypeChecked,
  ...tseslint.configs.recommendedTypeChecked,
  pluginReact.configs.flat.recommended,
  pluginReact.configs.flat["jsx-runtime"],
  prettierConfig,
  {
    ...importPlugin.flatConfigs.recommended,
    ...importPlugin.flatConfigs.typescript,
    ...importPlugin.flatConfigs.react,
    settings: { "import/resolver": { typescript: {} } },
    rules: {
      "import/order": [
        "error",
        {
          pathGroups: [
            {
              pattern: "@/**",
              group: "external",
              position: "after",
            },
          ],
          "newlines-between": "always",
          named: true,
          alphabetize: { order: "asc" },
        },
      ],
      "import/first": "error",
      "import/extensions": [
        "error",
        "always",
        {
          js: "never",
          jsx: "never",
          ts: "never",
          tsx: "never",
        },
      ],
      "@typescript-eslint/consistent-type-imports": "error",
      "react/prop-types": "off",
    },
  },
  {
    // Temporary strangler-migration exception for donor screens. New LMX code
    // must not be added to this list; remove entries as each screen is replaced.
    files: [
      "app/javascript/components/app-sidebar.tsx",
      "app/javascript/components/nav-main.tsx",
      "app/javascript/pages/candidates/**",
      "app/javascript/pages/client_companies/**",
      "app/javascript/pages/dashboard/**",
      "app/javascript/pages/interviews/**",
      "app/javascript/pages/jobs/**",
      "app/javascript/pages/meetings/**",
      "app/javascript/pages/onboarding/**",
      "app/javascript/pages/organizations/**",
      "app/javascript/pages/projects/**",
      "app/javascript/pages/settings/**",
      "app/javascript/pages/tasks/**",
    ],
    rules: {
      "import/order": "off",
      "@typescript-eslint/consistent-type-definitions": "off",
      "@typescript-eslint/no-base-to-string": "off",
      "@typescript-eslint/restrict-template-expressions": "off",
      "@typescript-eslint/prefer-nullish-coalescing": "off",
      "@typescript-eslint/consistent-type-imports": "off",
      "react-hooks/rules-of-hooks": "off",
    },
  },
  {
    files: ["**/*.js"],
    ...tseslint.configs.disableTypeChecked,
  },
]
