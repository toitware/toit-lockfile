// Copyright (C) 2025 Toit contributors.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the tests/TESTS_LICENSE file.

import host.directory

with-tmp-dir path/string [block]:
  dir := directory.mkdtemp path
  try:
    block.call dir
  finally:
    directory.rmdir --recursive --force dir
