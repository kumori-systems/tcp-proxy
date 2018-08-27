_before="$(git status)"
npm run build
_after="$(git status)"

if [ "$_before" = "$_after" ]; then
  echo "Evrythink seems OK. Going on..."
else
  git add lib/*
  echo "Source files recompiled and added"
fi
