/* Posacs bindings to POSIX functions

Copyright (C) 2025 Free Software Foundation, Inc.

GNU Emacs is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or (at
your option) any later version.

GNU Emacs is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with GNU Emacs.  If not, see <https://www.gnu.org/licenses/>.  */

#include <emacs-module.h>
#include <stdlib.h>
#include <string.h>

int plugin_is_GPL_compatible;

#define LISP_IS_NIL(env, val) \
  !(env)->is_not_nil (env, val)
#define LISP_IS_INTEGER(env, val) \
  (env)->eq ((env), (env)->type_of ((env), (val)), (env)->intern ((env), "integer"))
#define LISP_IS_FLOAT(env, val) \
  (env)->eq ((env), (env)->type_of ((env), (val)), (env)->intern ((env), "float"))
#define LISP_IS_STRING(env, val) \
  (env)->eq ((env), (env)->type_of ((env), (val)), (env)->intern ((env), "string"))

#define LISP_NIL(env) (env)->intern ((env), "nil")
#define LISP_T(env) (env)->intern ((env), "t")
#define LISP_SYM(env, x) (env)->intern ((env), x)
#define LISP_INT(env, x) (env)->make_integer ((env), (x))
#define LISP_FLOAT(env, x) (env)->make_float ((env), (x))
#define LISP_STR(env, x) (env)->make_string ((env), (x), strlen(x))

#define NON_LOCAL_EXIT_CHECK(env) \
  if ((env)->non_local_exit_check (env) != emacs_funcall_exit_return) {  \
    return LISP_NIL (env); \
  }

static char *
string_from_lisp(emacs_env *env, emacs_value val)
{
  ptrdiff_t size = 0;
  if (!env->copy_string_contents (env, val, NULL, &size))
    return 0;

  char *str = (char *)malloc (size);
  if (str == NULL) {
    env->non_local_exit_signal (env,
                                env->intern(env, "memory-full"),
                                LISP_NIL (env));
    return 0;
  }

  if (!env->copy_string_contents (env, val, str, &size)) {
      free (str);
      return 0;
  }
  return str;
}

static emacs_value
posacs_getenv(emacs_env *env,
              ptrdiff_t n,
              emacs_value *args,
              void *ptr) {
  (void)n;
  (void)ptr;
  char *var = NULL;
  emacs_value ret = LISP_NIL (env);
  if (LISP_IS_STRING (env, args[0])) {
      char *var = string_from_lisp (env, args[0]);
      if (var) {
        char *val = getenv (var);
        if (val)
          ret = LISP_STR (env, val);
      }
  }
  if (var) free (var);
  return ret;
}

static emacs_value
posacs_setenv(emacs_env *env,
              ptrdiff_t n,
              emacs_value *args,
              void *ptr) {
  (void)n;
  (void)ptr;
  char *var = NULL;
  char *val = NULL;
  emacs_value ret = LISP_NIL (env);
  if (LISP_IS_STRING (env, args[0])) {
      char *var = string_from_lisp (env, args[0]);
      if (var) {
        if (LISP_IS_STRING (env, args[1])) {
          char *val = string_from_lisp (env, args[1]);
          if (val)
            if (!setenv (var, val, 1))
              ret = LISP_T (env);
        }
      }
  }
  if (var) free (var);
  if (val) free (val);
  return ret;
}

static emacs_value
posacs_unsetenv(emacs_env *env,
              ptrdiff_t n,
              emacs_value *args,
              void *ptr) {
  (void)n;
  (void)ptr;
  char *var = NULL;
  emacs_value ret = LISP_NIL (env);
  if (LISP_IS_STRING (env, args[0])) {
      char *var = string_from_lisp (env, args[0]);
      if (var) {
        if (!unsetenv (var))
          ret = LISP_T (env);
      }
  }
  if (var) free (var);
  return ret;
}

static void
bind_func(emacs_env *env,
          const char *name,
          ptrdiff_t min,
          ptrdiff_t max,
          emacs_value (*function) (emacs_env *env,
                                   ptrdiff_t nargs,
                                   emacs_value args[],
                                   void *) EMACS_NOEXCEPT,
          const char *docstring) {
  emacs_value fset = LISP_SYM (env, "fset");
  emacs_value args[2];
  args[0] = LISP_SYM (env, name);
  args[1] = env->make_function (env, min, max, function, docstring, 0);
  env->funcall (env, fset, 2, args);
}

int
emacs_module_init(struct emacs_runtime *runtime) {
  if ((size_t)runtime->size < sizeof (*runtime))
    return 1; /* Require Emacs binary compatibility */
  emacs_env* env = runtime->get_environment(runtime);
  if ((size_t)env->size < sizeof (*env))
    return 2; /* Require Emacs binary compatibility */

  struct fun {
    const char *name;
    ptrdiff_t min_arity;
    ptrdiff_t max_arity;
    emacs_value (*function) (emacs_env *env,
                             ptrdiff_t nargs,
                             emacs_value args[],
                             void *) EMACS_NOEXCEPT;
    const char *docstring;
  };

  struct fun funcs[] = {
    { "posacs--getenv", 1, 1, posacs_getenv, "getenv internal" },
    { "posacs--setenv", 2, 2, posacs_setenv, "setenv internal" },
    { "posacs--unsetenv", 1, 1, posacs_unsetenv, "unsetenv internal" },
    { NULL, 0, 0, NULL, NULL }
  };

  for (int i = 0; funcs[i].name != NULL; ++i) {
    bind_func(env,
              funcs[i].name,
              funcs[i].min_arity,
              funcs[i].max_arity,
              funcs[i].function,
              funcs[i].docstring);
  }

  return 0;
}

/* posacs-module.c ends here */
