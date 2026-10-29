import js from "@eslint/js";
import globals from "globals";
import reactHooks from "eslint-plugin-react-hooks";
import tseslint from "typescript-eslint";
import prettier from "eslint-config-prettier";

export default tseslint.config(
  { ignores: ["dist", "dist-demo", "node_modules", "dev-dist"] },
  {
    extends: [js.configs.recommended, ...tseslint.configs.strict, prettier],
    files: ["**/*.{ts,tsx}"],
    languageOptions: { ecmaVersion: 2022, globals: globals.browser },
    plugins: { "react-hooks": reactHooks },
    rules: {
      ...reactHooks.configs.recommended.rules,
      "no-console": ["error", { allow: ["warn", "error"] }],
      eqeqeq: ["error", "smart"],
      "no-restricted-syntax": [
        "error",
        { selector: "Literal[value=/service_role/]", message: "Never use the service_role key in the dashboard." },
      ],
    },
  },
  { files: ["scripts/**/*.mjs"], languageOptions: { globals: globals.node } },
);
