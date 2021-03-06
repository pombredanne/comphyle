(import-from dulwich.repo Repo)
(import-from datetime datetime)
(import-from sh git dpkg-buildpackage)
(import-from dput upload)

(import glob)
(import re)
(import os)

(import-from comphyle.utils parse-rfc822 needs-build)
(import-from comphyle.native tmpwork)
(import-from comphyle.jinja render_fd)


(defn get-last-commit [path]
  (setf repo (Repo path))
  (setf *head* (.head repo))
  (setf commit (.get_object repo *head*))
  (, *head* commit.author (.utcfromtimestamp datetime commit.author_time)))


(defn pick-file [branch path fpath]
  (setf repo (Repo path))
  (setf *head* (get repo.refs (+ "refs/heads/" branch)))
  (grab-file-from-tree
    repo
    (.get-object repo (getattr (.get-object repo *head*) "tree"))
    fpath))


(defn pick-config-file [branch path fpath]
  (parse-rfc822 (.splitlines (getattr (pick-file branch path fpath) "data"))))


(defn grab-file-from-tree [repo tree fpath]
  (if (in "/" fpath)
    (do
      (setf (, local remote) (.split fpath "/" 1))
      (setf tree (.get-object repo (get (get tree local) 1)))
      (grab-file-from-tree repo tree remote))
    (.get-object repo (get (get tree fpath) 1))))


(defn get-repo-version [path init]
  (setf init (pick-file "master" path init))
  (.findall re "__version__ = \"(?P<version>.*)\"" init.data))


(defn generate-metadata [path config]
  (setf (, chash who ctime) (get-last-commit path))
  (setf version (get (get-repo-version path (get config "RootInit")) 0))
  (setf the-time (.strftime ctime "%Y%m%d"))
  (setf debstring (kwapply (.format "{version}+{when}.1.{hash}")
                           {"version" version
                            "when" the-time
                            "hash" (slice chash 0 8)}))
  {"hash" chash
   "author" who
   "when" ctime
   "version" debstring
   "config" config})


(defn check-build [repo branch compfile]
  (setf meta (generate-metadata
               repo
               (get (pick-config-file branch repo compfile) 0)))
  (setf (, archive suite section) (list-comp (get (get meta "config") x)
                                             [x ["ArchiveUrl"
                                                 "Suite"
                                                 "Section"]]))
  (needs-build archive suite section meta))


(defn render-package [context]
  (for [entries (.walk os "debian")]
    (setf (, dirpath dirnames filenames) entries)
    (for [fpath filenames]
      (if (.endswith fpath "jinja2")
        (render_fd (.join os.path dirpath fpath) context)))))


(defn workon-repo [path branch compfile]
  (setf path (.abspath os.path path))
  (setf meta (generate-metadata path (get (pick-config-file
                                            branch path compfile) 0)))
  (with [t-pth (tmpwork)]
        (.clone git path)
        (.chdir os (.replace (.basename os.path path) ".git" ""))
        (setf branch (get (get meta "config") "BuildBranch"))
        (.checkout git branch)
        (assoc meta "branch" branch)
        (.merge git "origin/debian" "--no-edit")
        (render-package meta)
        (dpkg-buildpackage "-us" "-uc")
        (.chdir os "..")
        (upload (get (.glob glob "*changes") 0)
                (get (get meta "config") "DputTarget"))))
