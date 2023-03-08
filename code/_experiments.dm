// This file contains experimental flags that may not be production ready yet,
// but that we want to be able to easily flip as well as run on CI.
// Any flag you see here can be flipped with the `-D` CLI argument.
// For example, if you want to enable EXPERIMENT_MY_COOL_FEATURE, compile with -DEXPERIMENT_MY_COOL_FEATURE

// EXPERIMENT_515_QDEL_HARD_REFERENCE
// - On 515, will hold a hard reference for qdeleted items, and check ref_count, rather than using refs.

// EXPERIMENT_515_ATOM_SPRITESHEETS
// - On 515, will use appearance references for spritesheets instead of blending them altogether.

#if DM_VERSION < 515

// You can't X-macro custom names :(

#ifdef EXPERIMENT_515_QDEL_HARD_REFERENCE
#warn EXPERIMENT_515_QDEL_HARD_REFERENCE is only available on 515+
#undef EXPERIMENT_515_QDEL_HARD_REFERENCE
#endif

#ifdef EXPERIMENT_515_ATOM_SPRITESHEETS
#warn EXPERIMENT_515_ATOM_SPRITESHEETS is only available on 515+
#undef EXPERIMENT_515_ATOM_SPRITESHEETS
#endif

#elif defined(UNIT_TESTS)

#define EXPERIMENT_515_ATOM_SPRITESHEETS
#define EXPERIMENT_515_QDEL_HARD_REFERENCE

#endif
#define EXPERIMENT_515_ATOM_SPRITESHEETS
