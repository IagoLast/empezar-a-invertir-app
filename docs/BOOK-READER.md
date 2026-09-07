# Book reader

Learn contains the complete manuscript from `libro-bolsa/manuscript/Book.txt`, in that order. The heading-only “Conceptos financieros básicos” file defines a section rather than an empty lesson, leaving 20 readable chapters. The source manuscript remains unchanged.

Run `npm run book:import` after updating the book submodule. The importer writes `packages/contracts/book.json` and the identical bundled iOS resource. Both are committed artifacts, so ordinary builds and CI do not need access to the private submodule. `npm run ios:prepare` copies the generated resource; it does not silently replace the manuscript. `node scripts/check-book.mjs` verifies every reader block against the retained source Markdown and, when available, against the submodule itself.

The reader preserves inline emphasis, headings, paragraphs, numbered and bulleted lists, and quotations. The diversification table becomes labelled rows suitable for a phone. Reading duration uses 200 words per minute. The book is bundled for offline use; no market or authentication request is needed to load chapters.

Completion, the last opened chapter and block bookmarks persist locally in UserDefaults, scoped by authenticated account ID (or guest). This is separate from the legacy four-lesson API progress and does not claim cloud synchronization. The reader supports Dynamic Type, an additional larger-text option, section jumps and sequential chapter navigation.

The bottom menu is a native SwiftUI TabView with independent stacks for Portfolio, Markets, Activity and Learn. It uses the system Liquid Glass appearance on iOS 26 without an opaque background or custom replacement. Activity has its own tab.
