require('dotenv').config({ path: '.upload.env' })

const Client = require('ssh2-sftp-client')
const path = require('path')
const fs = require('fs')

const sftp = new Client()

const config = {
    host: process.env.SFTP_HOST,
    port: parseInt(process.env.SFTP_PORT || '22', 10),
    username: process.env.SFTP_USERNAME,
    privateKey: fs.readFileSync(process.env.SFTP_PRIVATE_KEY),
}

const localDir = ['./lizmap.dir/instances/', process.env.SFTP_LOCAL_DIR].join('')
const remoteDir = ['./lizmap-docker-compose/lizmap/instances/', process.env.SFTP_REMOTE_DIR].join('')

async function uploadDirectory(local, remote) {
    const items = fs.readdirSync(local)

    try {
        await sftp.mkdir(remote, true)
    } catch (err) {
        if (err.code !== 4) {
            console.error(`Failed to make remote dir ${remote}: ${err.message}`)
        }
    }

    for (const item of items) {
        const localPath = path.join(local, item)
        const remotePath = path.posix.join(remote, item)

        if (fs.statSync(localPath).isDirectory()) {
            await uploadDirectory(localPath, remotePath)
        } else {
            console.log(`Uploading: ${localPath} -> ${remotePath}`)
            await sftp.put(localPath, remotePath)
        }
    }
}

async function main() {
    try {
        console.log(`Connecting to ${config.host}...`)
        await sftp.connect(config)
        await uploadDirectory(localDir, remoteDir)
        console.log('✅ Upload complete!')
    } catch (err) {
        console.error(`❌ Error: ${err.message}`)
    } finally {
        sftp.end()
    }
}

main()
