#!/usr/bin/env python3
"""Create portable backups and unpack into private staging directories."""

import pathlib
import shutil
import sys
import tarfile


def regular_member(member):
    if not (member.isdir() or member.isfile()):
        raise ValueError("backup contains a link or special file")
    return member


def pack(source):
    # dereference also disables hard-link entries, making backups self-contained.
    with tarfile.open(fileobj=sys.stdout.buffer, mode="w|gz", dereference=True) as archive:
        archive.add(source, arcname=".", filter=regular_member)


def unpack(archive_path, destination):
    destination = pathlib.Path(destination)
    with tarfile.open(archive_path, "r:gz") as archive:
        members = archive.getmembers()
        for member in members:
            path = pathlib.PurePosixPath(member.name)
            if path.is_absolute() or ".." in path.parts:
                raise ValueError("archive contains an unsafe path")
            if not (member.isdir() or member.isfile()):
                raise ValueError("archive contains a link or special file")
            if not path.parts and not member.isdir():
                raise ValueError("archive root must be a directory")
        for member in members:
            target = destination.joinpath(*pathlib.PurePosixPath(member.name).parts)
            target.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
            if member.isdir():
                target.mkdir(exist_ok=True, mode=0o700)
            else:
                with archive.extractfile(member) as source, target.open("xb") as output:
                    shutil.copyfileobj(source, output)
                target.chmod(0o600)


if __name__ == "__main__":
    try:
        if sys.argv[1] == "pack":
            pack(sys.argv[2])
        else:
            unpack(*sys.argv[2:])
    except (OSError, ValueError, tarfile.TarError) as error:
        sys.exit(f"[secret-archive] archive operation failed: {error}")
