from contextlib import contextmanager

from sh import dpkg
import sh

import tempfile
import shutil
import os


@contextmanager
def cd(path):
    old_dir = os.getcwd()
    os.chdir(path)
    try:
        yield
    finally:
        os.chdir(old_dir)


def rmdir(path):
    return shutil.rmtree(path)


@contextmanager
def tmpdir():
    path = tempfile.mkdtemp()
    try:
        yield path
    finally:
        pass
    rmdir(path)


@contextmanager
def tmpwork():
    with tmpdir() as tmp_path:
        with cd(tmp_path):
            yield tmp_path


class V(object):

    _opers = ["lt", "le", "eq", "ne", "ge", "gt"]

    def __init__(self, version_string):
        self.version_string = version_string

    def _cmp(self, oper, other):
        if not isinstance(other, V):
            raise TypeError("Stop sucking.")
        if oper not in self._opers:
            raise ValueError("Blow it out 'yer ass")

        try:
            dpkg("--compare-versions", self.version_string,
                 oper, other.version_string)
            return True
        except sh.ErrorReturnCode_1:
            return False

    def __lt__(self, other):
        return self._cmp("lt", other)

    def __le__(self, other):
        return self._cmp("le", other)

    def __eq__(self, other):
        return self._cmp("eq", other)

    def __ne__(self, other):
        return self._cmp("ne", other)

    def __gt__(self, other):
        return self._cmp("gt", other)

    def __ge__(self, other):
        return self._cmp("ge", other)

    def __repr__(self):
        return "<comhyle V - %s>" % (self.version_string)
