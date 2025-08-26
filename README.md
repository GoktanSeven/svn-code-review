# SVN Code Review

This repository provides a lightweight PowerShell script that helps developers perform code reviews on Subversion (SVN) repositories.

The script allows you to:
- Define a list of repositories in a JSON configuration file
- Specify the last reviewed revision for each repository
- Automatically list all commits (with author, date, message, and changed files) that need to be reviewed since the last reviewed revision

## Features
- Works with both working copy paths and direct SVN repository URLs
- Displays commit details in a clean and readable format
- Consistent reporting when no commits are found
- Uses your existing SVN authentication cache (no need to store credentials in config)
- Simple configuration using a JSON file

## Example
Configuration file `svn-repos.json`:
```json
[
  {
    "name": "ProjectA",
    "path": "C:\\work\\ProjectA",
    "lastReviewedRev": 12345
  },
  {
    "name": "CommonLibs",
    "path": "https://svn.example.com/svn/libs/common",
    "lastReviewedRev": 67890
  }
]
```

Run the script:
```powershell
.\review-svn.ps1
```

Example output:
```
================================================================================
ProjectA  (revisions to review: 12346 → 12400)
================================================================================
r12346 | jdoe | 2025-08-26 10:42:12 +02:00
  [M] /trunk/src/Foo.cs
  --- message ---
    Fixed null reference bug in Foo
```

## Requirements
- PowerShell 5.1+ (or PowerShell Core 7+)
- SVN command line client (`svn.exe`) available in the system PATH
- Valid credentials cached by SVN (or configured through your SVN client)

## License
MIT License
