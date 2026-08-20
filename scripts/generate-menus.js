// Generate ENiGMA menu files into /enigma-bbs-pre/config/menus, mirroring
// `oputil config new` (see core/oputil/oputil_config.js:233-284) so a fresh
// sealed config volume has menus without an interactive wizards run.
'use strict';

const fs = require('fs');
const path = require('path');

const BBS_DIR = process.env.BBS_ROOT_DIR || '/enigma-bbs';
const STAGE = '/enigma-bbs-pre/config/menus';

const boardName = 'OpenAllHours BBS';

const sanitize = (s) =>
    s.replace(/[^a-z0-9_-]/gi, '_').replace(/_+/g, '_').toLowerCase();

const boardSanitized = sanitize(boardName);
const dirName = path.join(STAGE);

fs.mkdirSync(dirName, { recursive: true });

const includeFilesIn = [
    'message_base.in.hjson',
    'private_mail.in.hjson',
    'login.in.hjson',
    'new_user.in.hjson',
    'doors.in.hjson',
    'file_base.in.hjson',
    'activitypub.in.hjson',
];

const includeFiles = [];
includeFilesIn.forEach((incFile) => {
    const outName = `${boardSanitized}-${incFile.replace('.in', '')}`;
    includeFiles.push(outName);
    const src = path.join(BBS_DIR, 'misc', 'menu_templates', incFile);
    if (!fs.existsSync(src)) {
        throw new Error(`missing menu template: ${src}`);
    }
    if (!fs.existsSync(path.join(dirName, outName))) {
        fs.copyFileSync(src, path.join(dirName, outName));
    }
});

const mainTemplate = fs
    .readFileSync(
        path.join(BBS_DIR, 'misc', 'menu_templates', 'main.in.hjson'),
        'utf8'
    )
    .replace(/%INCLUDE_FILES%/g, includeFiles.join('\n\t\t'));

const menuFile = `${boardSanitized}-main.hjson`;
const outPath = path.join(dirName, menuFile);
if (!fs.existsSync(outPath)) {
    fs.writeFileSync(outPath, mainTemplate, 'utf8');
}

console.log(`generated menus into ${dirName} (${menuFile})`);