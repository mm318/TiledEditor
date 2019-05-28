# Tiling Text Editor

Most multi-document text editors cycle through opened text files via tabs.

The goal of this project is to have viewports of opened text files organized in a tiled fashion, instead of via tabs.


## Build

- Requirements:
    - Qt5 is required
    - Tested on Ubuntu 16.04

- Obtain the source:

    ```bash
    $ git clone https://github.com/mm318/TiledEditor.git
    ```

- Build like an usual CMake project, for example:
    
    ```bash
    $ cd TiledEditor
    $ mkdir build
    $ cd build
    $ cmake ..
    $ make -j4

    ```
## Usage

```
./TiledEditor
```
