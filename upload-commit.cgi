#!/usr/bin/python
import cgitb;cgitb.enable()
import cgi,os, magic

authz_filename = '/var/www/html/Insurrection/auth/access'
repo_dir = '/var/www/svn'

def make_directory(repo,path,logmessage=''):
    import svn.core, svn.repos, svn.client, svn.fs
    pool = svn.core.Pool()
    ro = svn.repos.svn_repos_open(repo,pool)
    fs_obj = svn.repos.svn_repos_fs(ro)
    youngest_rev = svn.fs.svn_fs_youngest_rev(fs_obj, pool)
    txn = svn.fs.begin_txn(fs_obj,youngest_rev,pool)
    txn_root = svn.fs.svn_fs_txn_root(txn,pool)
    svn.fs.svn_fs_make_dir(txn_root,path,pool)
    svn.fs.svn_fs_change_txn_prop(txn,'svn:author',os.environ['REMOTE_USER'])
    svn.fs.commit_txn(txn)
    print """<html><head><title>CREATED</title></head>
    <body><h1>Created %s created.</h1> </body></html>""" %(path)



def get_mime_type(data):
    checker = magic.open(magic.MAGIC_MIME)
    checker.load()
    return(checker.buffer(data))

def load_new_file(repo,path,data,logmessage):
    """ Does the entire transaction. """
    import svn.core, svn.repos, svn.client, svn.fs
    #    try:
    pool = svn.core.Pool()
    ro = svn.repos.svn_repos_open(repo,pool)
    fs_obj = svn.repos.svn_repos_fs(ro)
    youngest_rev = svn.fs.svn_fs_youngest_rev(fs_obj, pool)
    root_obj = svn.fs.svn_fs_revision_root(fs_obj, youngest_rev, pool)
    #    except :
    #        # This calls for putting some info out the browser.
    #        print 'Content-type: text/html'
    #        print
    #        print """<html><head><title>Error</title></head>
    #        <body><h1>Exception thrown</h1>"""
    #        print "Opening repo %s for %s " % (repo,path)
    #        print """ </body></html>"""
    #    try:
    txn = svn.fs.begin_txn(fs_obj,youngest_rev,pool)
    #    txn2 = svn.fs.begin_txn(root_obj,youngest_rev,pool)
    t = get_mime_type(data)
    svn.fs.svn_fs_change_txn_prop(txn,'svn:log',logmessage)
    svn.fs.svn_fs_change_txn_prop(txn,'svn:author',os.environ['REMOTE_USER'])
    # TODO: test for file already existing. 
    if svn.fs.is_file(root_obj,path):
        print """<html><head><title>File Exists</title></head>
    <body><h1>File %s already exists.</h1>Please go Back and choose another name. </body></html>""" %(path)
        return False
    svn.fs.svn_fs_make_file(svn.fs.svn_fs_txn_root(txn),path,None)
    svn.fs.svn_fs_change_node_prop(svn.fs.svn_fs_txn_root(txn),path,'svn:mime-type',t,pool)
    app = svn.fs.apply_text(svn.fs.svn_fs_txn_root(txn),path,None)
    svn.core.svn_stream_write(app,data)
    svn.core.svn_stream_close(app)
    svn.fs.commit_txn(txn)
    #    svn.fs.commit_txn(txn2)
    #    except :
    #        # This calls for putting some info out the browser.
    #        print 'Content-type: text/html'
    #        print
    #        print """<html><head><title>Error</title></head>
    #        <body><h1>Exception thrown</h1>"""
    #        print "Opening file in repo %s for %s " % (repo,path)
    #        print """ </body></html>"""
    #    else:
    print """<html><head><title>CREATED</title></head>
    <body><h1>File %s created. Type %s</h1> </body></html>""" %(path,t)


def load_new_version(repo,path,data,logmessage):
    """ Does the entire transaction. """
    import svn.core, svn.repos, svn.client, svn.fs,svn.delta,svn.ra
    #    try:
    pool = svn.core.Pool()
    ro = svn.repos.svn_repos_open(repo,pool)
    fs_obj = svn.repos.svn_repos_fs(ro)
    youngest_rev = svn.fs.svn_fs_youngest_rev(fs_obj, pool)
    #    except :
    #        # This calls for putting some info out the browser.
    #        print 'Content-type: text/html'
    #        print
    #        print """<html><head><title>Error</title></head>
    #        <body><h1>Exception thrown</h1>"""
    #        print "Opening repo %s for %s " % (repo,path)
    #        print """ </body></html>"""
    #    try:
    txn = svn.fs.begin_txn(fs_obj,youngest_rev,pool)
    svn.fs.svn_fs_change_txn_prop(txn,'svn:log',logmessage)
    svn.fs.svn_fs_change_txn_prop(txn,'svn:author',os.environ['REMOTE_USER'])
    app = svn.fs.apply_text(svn.fs.svn_fs_txn_root(txn),path,None)
    svn.core.svn_stream_write(app,data)
    svn.core.svn_stream_close(app)
    svn.fs.commit_txn(txn)
    #    except :
    #        # This calls for putting some info out the browser.
    #        print 'Content-type: text/html'
    #        print
    #        print """<html><head><title>Error</title></head>
    #        <body><h1>Exception thrown</h1>"""
    #        print "Opening file in repo %s for %s " % (repo,path)
    #        print """ </body></html>"""
    #    else:
    #        print 'Content-type: text/html'
    #        print
    #        print """<html><head><title>Uploaded</title></head>
    #        <body><h1>It Worked.</h1>"""
    #        print "%s uploaded to %s by %s" % path,repo,os.environ['REMOTE_USER']
    #        print """ </body></html>"""
    print """<html><head><title>updated</title></head>
    <body><h1>File %s updated.</h1> </body></html>""" %(path)


def check_authorization(username,repo):
    """ Check against the central authorization file that we have 'rw' """
    import ConfigParser
    c = ConfigParser.ConfigParser()
    c.read(authz_filename)
    return c.has_section(repo) and c.has_option(repo,username) and c.get(repo,username) == 'rw'
#        return True
#    else :
#        return False

    

def main():
    print 'Content-type: text/html'
    print
    # TODO: Test for field values. 
    form=cgi.FieldStorage()
    repo = form.getvalue('repo')
    path = form.getvalue('uploadpath')
    log = form.getvalue('logmessage')
    filename = form.getvalue('filename')
    if check_authorization(os.environ['REMOTE_USER'],repo +':/'):
        if form.has_key('makedir'):
            make_directory(repo_dir +'/'+ repo,path+'/'+filename,log)
        elif form.has_key('filename'):
            data = form.getvalue('ufile')
            load_new_file(repo_dir +'/'+ repo,path+'/'+filename,data,log)
        else:
            data = form.getvalue('ufile')
            load_new_version(repo_dir +'/'+ repo,path,data,log)
    else:
        print """<html><head><title>NOT AUTHORIZED</title></head>
        <body><h1>You do not have write access.</h1>"""
        print "You were not able to add %s  to %s as %s" % (path,repo,os.environ['REMOTE_USER'])
        print """ </body></html>"""


main()
