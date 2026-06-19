#!/bin/bash
# mkdir --parents ../RELEASE/$COURSE_NAME/outlines/; mv $COURSE_NAME_$(git describe --tags --abbrev=0.txt) $_
# Function to prompt user to continue or exit
prompt_continue() {
    while true; do
        read -p "Would you like to continue? (y/n): " choice
        case $choice in
            [Yy]* ) break;;
            [Nn]* ) exit;;
            * ) echo "Please answer y or n.";;
        esac
    done
}

# Default organization name
ORGANIZATION_NAME="lftraining"

# Prompt user for inputs
echo "Prompting user for course details..."
read -p "Enter the name of the course (COURSE_NAME): " COURSE_NAME
read -p "Enter the repository to build (COURSE_REPO): " COURSE_REPO
read -p "Enter the version of the course (ILT version should be provided by maintainer/author and should be in something like #.#.# format. Do NOT put a 'v' in front) (e-learning version is format yyyy-mm-dd) (VERSION): " VERSION
read -p "Enter 'e' for elearning or 'i' for ILT: " COURSE_TYPE

echo "User inputs received."
prompt_continue

# Create and navigate to lftraining directory
echo "Creating and navigating to lftraining directory..."
mkdir -p lftraining
cd lftraining

echo "Navigated to lftraining directory."
prompt_continue

# Clone necessary repositories if they don't exist
echo "Cloning necessary repositories..."
[ ! -d "LFCW" ] && git clone git@github.com:$ORGANIZATION_NAME/LFCW.git
cd LFCW
[ ! -d "common" ] && git clone git@github.com:$ORGANIZATION_NAME/common.git
cd ..
[ ! -d "cm-interaction" ] && git clone git@github.com:$ORGANIZATION_NAME/cm-interaction.git

echo "Repositories cloned."
prompt_continue

# Sync cm-interaction
echo "Creating local course directory for cm-interaction..."
mkdir -p cm-interaction/$COURSE_NAME
# cd cm-interaction
# echo "y" | ./sync_cm_download.sh $COURSE_NAME
# cd ..

echo "Local course directory in cm-interaction directory created."
prompt_continue

# Clone course repo inside LFCW (ephemeral: wipe any stale copy first)
echo "Cloning course repository inside LFCW..."
cd LFCW
LFCW_DIR="$(pwd)"

# Ephemeral build: remove any prior checkout so submodules are always re-fetched fresh
echo "Removing any existing course build directory for a clean checkout..."
[ -n "$COURSE_REPO" ] && rm -rf "$LFCW_DIR/$COURSE_REPO"
[ -n "$COURSE_NAME" ] && rm -rf "$LFCW_DIR/$COURSE_NAME"

# Avoid version collisions on re-runs: clear any prior RELEASE output for this version
echo "Removing any existing RELEASE output for $COURSE_NAME V$VERSION..."
[ -n "$COURSE_NAME" ] && [ -n "$VERSION" ] && rm -rf "$LFCW_DIR/RELEASE/$COURSE_NAME/V$VERSION"

git clone git@github.com:$ORGANIZATION_NAME/$COURSE_REPO.git

echo "Course repository cloned inside LFCW."
prompt_continue

# Create RELEASE directory
echo "Creating RELEASE directory..."
mkdir -p RELEASE/$COURSE_NAME
mkdir RELEASE/BLURBS
echo "RELEASE directory created."
prompt_continue

# Create softlink for elearning
if [ "$COURSE_TYPE" == "e" ]; then
    echo "Creating softlink for elearning..."
    ln -s $COURSE_REPO $COURSE_NAME
fi

echo "Softlink created for elearning (if applicable)."
prompt_continue

cd $COURSE_NAME

# Re-run safety: drop any existing tag for this version locally and on GitHub
# so the tag + push below can recreate it cleanly on the new commit.
echo "Deleting any existing '$VERSION' tag (local + remote) to avoid collisions..."
git tag -d "$VERSION" 2>/dev/null || true
git push --delete origin "$VERSION" 2>/dev/null || true

# Update version number in .tex file
echo "Updating version number in .tex file..."
sed -i 's/\\newcommand{\\version}{.*}/\\newcommand{\\version}{'$VERSION'}/' ${COURSE_NAME}.tex


prompt_continue

echo "Version number updated in .tex file."
echo "Updated version line:"
grep "\\newcommand{\\version}{" ${COURSE_NAME}.tex

prompt_continue

# Check and update submodules
echo "Checking and updating submodules..."
git submodule update --init --recursive

echo "Submodules checked and updated."
prompt_continue

# Commit and tag the changes
echo "Committing and tagging the changes..."
git commit -asm "Version $VERSION"
git tag $VERSION
git push
git push --tags

echo "Changes committed and tagged."

prompt_continue

# Create BINARIES directory
echo "Creating BINARIES directory..."
mkdir -p BINARIES

echo "BINARIES directory created."
prompt_continue

# Run cmtool download
echo "Running cmtool download..."
./common/UTILS/cmtool download || echo "cmtool download failed."

echo "cmtool download completed or failed. IT IS OK TO FAIL IF THIS PARTICULAR COURSE DOES NOT HAVE RESOURCES TO DOWNLOAD."
prompt_continue

# Run make command based on course type
if [ "$COURSE_TYPE" == "e" ]; then
    cd ../$COURSE_REPO
    make clean
    cd ../$COURSE_NAME
    echo "Running make for elearning..."
    docker run --rm -v $(pwd):/$(basename $(pwd)) --user $(id -u):$(id -g) --workdir /$(basename $(pwd)) eeganlf/tex-build:v1.0 /bin/bash -c "make release-elearning"
else
    echo "Running make for ILT..."
    docker run --rm -v $(pwd):/$(basename $(pwd)) --user $(id -u):$(id -g) --workdir /$(basename $(pwd)) eeganlf/tex-build:v1.0 /bin/bash -c "make release-full"
fi

echo "Make command executed based on course type."
prompt_continue

# Navigate back to LFCW and run release_and_upload.sh
echo "Navigating back to LFCW and running release_and_upload.sh..."
cd ..
./release_and_upload.sh $COURSE_NAME

echo "Navigated back to LFCW and ran release_and_upload.sh."
prompt_continue
echo "Cleaning up"
cd $COURSE_NAME
make clean
cd ..

# Copy SOL and RES files
echo "Copying SOL and RES files..."
cp RELEASE/$COURSE_NAME/V$VERSION/*SOL* ../cm-interaction/$COURSE_NAME/
cp RELEASE/$COURSE_NAME/V$VERSION/*RES* ../cm-interaction/$COURSE_NAME/

echo "SOL and RES files copied."
prompt_continue

# Sync cm-interaction
echo "Syncing cm-interaction..."
cd ../cm-interaction
chmod +x sync_cm_nodelete.sh
./sync_cm_nodelete.sh $COURSE_NAME

echo "cm-interaction synced."
prompt_continue

# Reminders
if [ "$COURSE_TYPE" == "i" ]; then
   echo "Reminding user of post-script actions..."
   echo "Don’t forget to compare LFCW/RELEASE/$COURSE_NAME/V$VERSION/"$COURSE_NAME"-long-outline_V"$VERSION.html  " with outline on wordpress site (https://training.linuxfoundation.org/wp-admin) and update wordpress site if necessary. Documentation for updating can be found here: https://confluence.linuxfoundation.org/display/TC/Updating+Wordpress+Site+Outline, Reach out to marketing for wordpress access if you don't have access."
   echo "Don’t forget to upload the following files found in the RELEASE/$COURSE_NAME/V$VERSION directory:" $COURSE_NAME"_"$VERSION.pdf", $COURSE_NAME-COVER-FRONT_V$VERSION.pdf and $COURSE_NAME-COVER-BACK_V$VERSION.pdf pdfs to printer at https://upload.zebraprintsolutions.com/index-sales.php"
   echo "Don’t forget to update version to $VERSION in https://docs.google.com/spreadsheets/d/1zCsRyPDufgLK4ihgZ1x4iLZsjLaOZceDl1dA5hf1pqw/edit#gid=0"
   echo "Don’t forget to email instructors@lists.linuxfoundation.org with subject: Release of $COURSE_NAME version $VERSION 
   message: Hi All, It is our pleasure to announce the release of version $VERSION of $COURSE_NAME. Authors and/or maintainers may wish to comment further on this release."
else
    echo "Elearning All Done!"
fi

# Create printer directory with the three PDFs needed for the print upload
if [ "$COURSE_TYPE" == "i" ]; then
    echo "Creating printer directory..."
    PRINTER_DIR="$LFCW_DIR/RELEASE/$COURSE_NAME/V$VERSION/printer"
    mkdir -p "$PRINTER_DIR"
    cp "$LFCW_DIR/RELEASE/$COURSE_NAME/V$VERSION/${COURSE_NAME}_V${VERSION}.pdf" "$PRINTER_DIR/"
    cp "$LFCW_DIR/RELEASE/$COURSE_NAME/V$VERSION/${COURSE_NAME}-COVER-FRONT_V${VERSION}.pdf" "$PRINTER_DIR/"
    cp "$LFCW_DIR/RELEASE/$COURSE_NAME/V$VERSION/${COURSE_NAME}-COVER-BACK_V${VERSION}.pdf" "$PRINTER_DIR/"
    echo "Printer directory created: $PRINTER_DIR"
fi

# Ephemeral build: remove the course checkout now that the release is complete
echo "Removing ephemeral course build directory..."
[ -n "$COURSE_REPO" ] && rm -rf "$LFCW_DIR/$COURSE_REPO"
[ -n "$COURSE_NAME" ] && rm -rf "$LFCW_DIR/$COURSE_NAME"

# Print key release files with absolute paths (Ctrl/Cmd+Click to open in VSCode)
RELEASE_DIR="$LFCW_DIR/RELEASE/$COURSE_NAME/V$VERSION"
echo ""
echo "==================================================================="
echo "Key release files (Ctrl+Click / Cmd+Click to open in VSCode):"
echo "$RELEASE_DIR/${COURSE_NAME}_V${VERSION}.pdf"
echo "$RELEASE_DIR/${COURSE_NAME}-long-outline_V${VERSION}.html"
echo "==================================================================="
