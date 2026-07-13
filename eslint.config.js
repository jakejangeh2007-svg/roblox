import tseslint from 'typescript-eslint';

export default tseslint.config(
  ...tseslint.configs.recommendedTypeChecked,
  {
    languageOptions: {
      parserOptions: {
        projectService: true,
        tsconfigRootDir: import.meta.dirname,
      },
    },
    rules: {
      '@typescript-eslint/no-unused-vars': [
        'error',
        { argsIgnorePattern: '^_', varsIgnorePattern: '^_' },
      ],
      // Voxel engines index typed arrays constantly; non-null assertions after
      // bounds checks are idiomatic and faster than optional chains in hot paths.
      '@typescript-eslint/no-non-null-assertion': 'off',
      // Block IDs are stored as raw bytes in Uint8Arrays and compared against
      // BlockId enum constants throughout — that's the intended data model, so
      // number-vs-enum comparisons are expected, not unsafe.
      '@typescript-eslint/no-unsafe-enum-comparison': 'off',
    },
  },
  {
    files: ['**/*.test.ts'],
    rules: {
      '@typescript-eslint/no-floating-promises': 'off',
    },
  },
);
