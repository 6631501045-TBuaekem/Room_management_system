const express = require('express');
const pool = require('./config/db.js');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const mysql = require('mysql2'); // keep for pool compatibility if needed

const app = express();

app.use(express.json());
app.use(express.urlencoded({ extended: true }));

const JWT_KEY = 'room-reservation';
const JWT_EXPIRES = '24h'; // token lifetime

// ==================== Time simulation utilities ====================
const timesim = 9; // null = real time, 6 reset status

function getNowDate() {
  if (timesim === null) return new Date();
  const now = new Date();
  return new Date(now.getFullYear(), now.getMonth(), now.getDate(), timesim, 0, 0, 0);
}

function getCurrentHourFrac() {
  const d = getNowDate();
  return d.getHours() + d.getMinutes() / 60;
}

function getCurrentTime() {
  const d = getNowDate();
  return { hour: d.getHours(), minute: d.getMinutes() };
}

function isEarlyMorningReset(time) {
  return time.hour === 6;
}

function isEndOfDay(time) {
  return time.hour >= 17;
}

// ==================== Auth middleware (multi-role support) ====================
function verifyUser(requiredRoles = null) {
  // requiredRoles can be null (any authenticated), a string like "0", or array like ["1","2"]
  const rolesArray = requiredRoles == null
    ? null
    : (Array.isArray(requiredRoles) ? requiredRoles : [requiredRoles]);

  return (req, res, next) => {
    let token = req.headers['authorization'] || req.headers['x-access-token'];
    if (!token) return res.status(400).send('No token');

    if (req.headers.authorization) {
      const parts = token.split(' ');
      if (parts.length === 2 && parts[0] === 'Bearer') token = parts[1];
    }

    jwt.verify(token, JWT_KEY, (err, decoded) => {
      if (err) return res.status(401).send('Incorrect token');

      if (rolesArray && !rolesArray.includes(String(decoded.role))) {
        return res.status(403).send('Unauthorized');
      }

      req.decoded = decoded; // { uid, username, name, role, iat, exp }
      next();
    });
  };
}

// ==================== AUTH ROUTES ====================
// POST /login  body: { username, password }
app.post("/login", async function (req, res) {
  const { username, password } = req.body;
  if (!username || !password) return res.status(400).send("Username and password required");

  try {
    const connection = await pool.promise().getConnection();
    try {
      const sql = `SELECT UserID, name, username, role, password FROM users WHERE username = ?`;
      const [rows] = await connection.query(sql, [username]);

      if (rows.length !== 1) {
        return res.status(401).send("Wrong username or password");
      }

      const user = rows[0];
      const isHashed = typeof user.password === 'string' && user.password.startsWith('$2b$');
      let match = false;

      if (isHashed) {
        match = await bcrypt.compare(password, user.password);
      } else {
        match = password === user.password;
        if (match) {
          const hashedPassword = await bcrypt.hash(password, 10);
          await connection.query(`UPDATE users SET password = ? WHERE UserID = ?`, [hashedPassword, user.UserID]);
        }
      }

      if (!match) return res.status(401).send("Wrong username or password");

      // format id for response (keeps original behaviour)
      const userIdStr = user.UserID.toString().padStart(3, '0');
      let formattedId;
      switch (user.role) {
        case "0": formattedId = `U${userIdStr}`; break;
        case "1": formattedId = `S${userIdStr}`; break;
        case "2": formattedId = `A${userIdStr}`; break;
        default: formattedId = userIdStr;
      }

      const payload = {
        uid: user.UserID,
        username: user.username,
        name: user.name,
        role: user.role
      };

      const token = jwt.sign(payload, JWT_KEY, { expiresIn: JWT_EXPIRES });

      return res.status(200).json({
        message: "Login Successful",
        token,
        role: user.role,
        userId: user.UserID,
        formattedId,
        name: user.name,
        username: user.username
      });
    } finally {
      connection.release();
    }
  } catch (err) {
    console.error("Database error:", err);
    return res.status(500).send("Database Server Error");
  }
});

// POST /register body: { name, username, password, role }
app.post("/register", async function (req, res) {
  const { name, username, password, role } = req.body;
  if (!name || !username || !password) return res.status(400).json({ message: "All fields are required" });

  try {
    const connection = await pool.promise().getConnection();
    try {
      const [existing] = await connection.query(`SELECT * FROM users WHERE username = ?`, [username]);
      if (existing.length > 0) return res.status(409).json({ message: "Username already exists" });

      const hashedPassword = await bcrypt.hash(password, 10);
      await connection.query(`INSERT INTO users (name, username, password, role) VALUES (?, ?, ?, ?)`, [name, username, hashedPassword, role || "0"]);

      return res.status(200).json({ message: "Registration Successful" });
    } finally {
      connection.release();
    }
  } catch (err) {
    console.error("Database error:", err);
    return res.status(500).json({ message: "Database Server Error" });
  }
});

// POST /logout
// With JWT there's no strict server-side logout unless you maintain a blacklist.
// This endpoint exists for parity: client should delete token. Here we respond OK.
app.post("/logout", verifyUser(), function (req, res) {
  res.status(200).json({ message: "Logged out successful" });
});

// GET /profile
app.get('/profile', verifyUser(), async function (req, res) {
  const username = req.decoded?.username;
  if (!username) return res.status(401).json({ message: 'Not logged in' });

  try {
    const connection = await pool.promise().getConnection();
    try {
      const [rows] = await connection.query(`SELECT name, username FROM users WHERE username = ?`, [username]);
      if (rows.length === 0) return res.status(404).json({ message: 'User not found' });

      return res.status(200).json({
        name: rows[0].name,
        username: rows[0].username,
        role: req.decoded.role
      });
    } finally {
      connection.release();
    }
  } catch (err) {
    console.error("Database error:", err);
    return res.status(500).json({ message: 'Database Server Error' });
  }
});

// GET /rooms/info?date=YYYY-MM-DD
app.get("/rooms/info", verifyUser(["0","1","2"]), async function (req, res) {
  // Anyone authenticated can view room info (0=user,1=staff,2=approver)
  const selectedDate = req.query.date;
  if (!selectedDate) return res.status(400).json({ message: "Date query is required" });

  try {
    const connection = await pool.promise().getConnection();
    try {
      const sql = `
        SELECT 
          r.room_id,
          r.room_name,
          r.room_description,
          r.timestatus8,
          r.timestatus10,
          r.timestatus13,
          r.timestatus15,
          b.booking_time,
          b.booking_status,
          b.User_id,
          u.username AS user_name
        FROM room r
        LEFT JOIN booking b 
            ON r.room_name = b.room_name  
            AND b.booking_date = ?
            AND b.booking_status != 'reject'
        LEFT JOIN users u ON b.User_id = u.UserID
        ORDER BY r.room_name
      `;

      const [result] = await connection.query(sql, [selectedDate]);

      const currentHour = getCurrentHourFrac();
      const slotRanges = {
        "08.00 - 10.00": [8, 10],
        "10.00 - 12.00": [10, 12],
        "13.00 - 15.00": [13, 15],
        "15.00 - 17.00": [15, 17]
      };

      const rooms = {};

      result.forEach(row => {
        if (!rooms[row.room_name]) {
          const timeSlots = {
            "08.00 - 10.00": row.timestatus8,
            "10.00 - 12.00": row.timestatus10,
            "13.00 - 15.00": row.timestatus13,
            "15.00 - 17.00": row.timestatus15
          };

          for (const [key, value] of Object.entries(timeSlots)) {
            const [, end] = slotRanges[key];
            if (end <= currentHour || value === 'Unavailable') {
              delete timeSlots[key];
            }
          }

          rooms[row.room_name] = {
            room_id: row.room_id,
            room_name: row.room_name,
            room_description: row.room_description,
            timeSlots
          };
        }

        if (row.booking_time) {
          const time = row.booking_time.toString();
          const slotMap = {
            "8": "08.00 - 10.00",
            "10": "10.00 - 12.00",
            "13": "13.00 - 15.00",
            "15": "15.00 - 17.00"
          };
          const slot = slotMap[row.booking_time?.toString()];

          if (slot && rooms[row.room_name].timeSlots[slot] !== undefined) {
            if (row.booking_status === 'approve') rooms[row.room_name].timeSlots[slot] = 'Reserved';
            else if (row.booking_status === 'pending') rooms[row.room_name].timeSlots[slot] = 'Pending';
          }
        }
      });

      res.status(200).json(Object.values(rooms));
    } finally {
      connection.release();
    }
  } catch (err) {
    console.error("Database error:", err);
    res.status(500).json({ message: "Database Server Error" });
  }
});


// ========================= FETCH REQUEST ROOM (ROLE 0) ===============================
app.get("/rooms/request/info", verifyUser(["0"]), async function (req, res) {
  const selectedDate = req.query.date;
  if (!selectedDate) return res.status(400).json({ message: "Date query is required" });

  try {
    const connection = await pool.promise().getConnection();
    try {
      const sql = `
        SELECT 
          r.room_id,
          r.room_name,
          r.room_description,
          r.timestatus8,
          r.timestatus10,
          r.timestatus13,
          r.timestatus15,
          b.booking_time,
          b.booking_status,
          b.User_id,
          u.username as user_name
        FROM room r
        LEFT JOIN booking b 
           ON r.room_name = b.room_name 
           AND b.booking_date = ?
        LEFT JOIN users u ON b.User_id = u.UserID
        ORDER BY r.room_name
      `;

      const [result] = await connection.query(sql, [selectedDate]);
      const currentHour = getCurrentHourFrac();

      const slotRanges = {
        "08.00 - 10.00": [8, 10],
        "10.00 - 12.00": [10, 12],
        "13.00 - 15.00": [13, 15],
        "15.00 - 17.00": [15, 17]
      };

      const todayIso = getNowDate().toISOString().split("T")[0];
      const isToday = selectedDate === todayIso;

      const rooms = {};

      result.forEach(row => {
        if (!rooms[row.room_name]) {
          const allSlots = {
            "08.00 - 10.00": row.timestatus8,
            "10.00 - 12.00": row.timestatus10,
            "13.00 - 15.00": row.timestatus13,
            "15.00 - 17.00": row.timestatus15
          };

          const freeSlots = Object.fromEntries(
            Object.entries(allSlots).filter(([key, status]) => {
              if (status !== "Free") return false;
              if (isToday) {
                const [, end] = slotRanges[key];
                return end > currentHour;
              }
              return true;
            })
          );

          if (Object.keys(freeSlots).length > 0) {
            rooms[row.room_name] = {
              room_id: row.room_id,
              room_name: row.room_name,
              room_description: row.room_description,
              timeSlots: freeSlots
            };
          }
        }
      });

      res.status(200).json(Object.values(rooms));
    } finally {
      connection.release();
    }
  } catch (err) {
    console.error("Database error:", err);
    return res.status(500).json({ message: "Database Server Error" });
  }
});

// POST /rooms/request body: { room_id, date, timeSlot, reason }
// ========================= SUBMIT ROOM REQUEST (ROLE 0) ===============================
app.post("/rooms/request", verifyUser(["0"]), async function (req, res) {
  const uid = req.decoded.uid;
  const { room_id, date, timeSlot, reason } = req.body;

  if (!room_id || !date || !timeSlot || !reason)
    return res.status(400).json({ message: "Missing required fields" });

  let connection;

  try {
    connection = await pool.promise().getConnection();
    await connection.beginTransaction();

    // 1) ensure user doesn't have booking for same date
    const [existing] = await connection.query(
      `SELECT * FROM booking WHERE User_id = ? AND booking_date = ? AND booking_status != 'reject'`,
      [uid, date]
    );

    if (existing.length > 0) {
      await connection.rollback();
      return res.status(400).json({ message: "You already have a booking for this date" });
    }

    // 2) check room availability
    const [r] = await connection.query(
      `SELECT * FROM room WHERE room_id = ? AND timestatus${timeSlot} = 'Free'`,
      [room_id]
    );

    if (r.length === 0) {
      await connection.rollback();
      return res.status(400).json({ message: "Room is not available for the selected time slot" });
    }

    // 3) insert new booking
    await connection.query(
      `INSERT INTO booking (User_id, room_id, booking_date, booking_time, reason, booking_status)
       VALUES (?, ?, ?, ?, ?, 'pending')`,
      [uid, room_id, date, timeSlot, reason]
    );

    // 4) update room slot
    await connection.query(
      `UPDATE room SET timestatus${timeSlot} = 'Pending' WHERE room_id = ?`,
      [room_id]
    );

    await connection.commit();
    return res.status(200).json({ message: "Reservation submitted successfully" });
  } catch (err) {
    if (connection) await connection.rollback();
    console.error("Database error:", err);
    return res.status(500).json({ message: "Database Server Error" });
  } finally {
    if (connection) connection.release();
  }
});

// GET /rooms/check/info?date=YYYY-MM-DD
// ========================= CHECK ROOM REQUEST (ROLE 0) ===============================
app.get("/rooms/check/info", verifyUser(["0"]), async function (req, res) {
  const uid = req.decoded.uid;

  try {
    const connection = await pool.promise().getConnection();
    try {
      const sql = `
        SELECT 
          b.*,
          r.room_name,
          r.room_description
        FROM booking b
        JOIN room r ON b.room_id = r.room_id
        WHERE b.User_id = ?
        AND b.booking_date = CURDATE()
        ORDER BY b.booking_date DESC, b.booking_time DESC, b.request_id DESC
      `;
      const [result] = await connection.query(sql, [uid]);

      if (result.length === 0) {
        return res.status(200).json({ bookings: [] });
      }

      const timeSlotMap = {
        "8": "08:00 - 10:00",
        "10": "10:00 - 12:00",
        "13": "13:00 - 15:00",
        "15": "15:00 - 17:00"
      };

      const formatted = result.map(b => {
        const dateObj = new Date(b.booking_date);
        const formattedDate =
          `${String(dateObj.getDate()).padStart(2, "0")}/${String(dateObj.getMonth() + 1).padStart(2, "0")}/${dateObj.getFullYear()}`;

        const timeLabel = timeSlotMap[b.booking_time?.toString()] || "-";

        return {
          request_id: b.request_id,
          room_name: b.room_name,
          room_description: b.room_description,
          booking_date: formattedDate,
          booking_time: timeLabel,
          booking_status: b.booking_status,
          reason: b.reason,
          reject_reason: b.reject_reason
        };
      });

      return res.status(200).json({ bookings: formatted });
    } finally {
      connection.release();
    }
  } catch (err) {
    console.error("Database error:", err);
    return res.status(500).json({ message: "Database Server Error" });
  }
});



// ========================= FETCH ROOM (ROLE 1) ===============================
app.get('/rooms/manage/info', verifyUser(["1"]), async function (req, res) {
  try {
    const connection = await pool.promise().getConnection();
    try {
      const sql = `
        SELECT 
          room_id,
          room_name,
          room_description,
          timestatus8,
          timestatus10,
          timestatus13,
          timestatus15
        FROM room
        ORDER BY room_name
      `;

      const [rows] = await connection.query(sql);

      const currentHour = getCurrentHourFrac();

      const slotRanges = {
        timestatus8: [8, 10],
        timestatus10: [10, 12],
        timestatus13: [13, 15],
        timestatus15: [15, 17]
      };

      const timeMap = {
        timestatus8: "08:00 - 10:00",
        timestatus10: "10:00 - 12:00",
        timestatus13: "13:00 - 15:00",
        timestatus15: "15:00 - 17:00"
      };

      const formatted = rows
        .map(room => {
          const timeSlots = {};

          for (const [key, label] of Object.entries(timeMap)) {
            const [, end] = slotRanges[key];

            if (
              room[key] === "Disable" ||
              (room[key] === "Free" && end > currentHour)
            ) {
              timeSlots[label] = room[key];
            }
          }

          return {
            room_id: room.room_id,
            room_name: room.room_name,
            room_description: room.room_description,
            timeSlots
          };
        })
        .filter(room => Object.keys(room.timeSlots).length > 0);

      return res.status(200).json(formatted);

    } finally {
      connection.release();
    }
  } catch (err) {
    console.error("Database error:", err);
    return res.status(500).json({ message: "Database Server Error" });
  }
});


// POST /rooms/manage/add body: { room_name, room_description }
// ========================== ADD ROOM (ROLE: 1)======================
app.post('/rooms/manage/add', verifyUser(["1"]), async function (req, res) {
  const { room_name, room_description } = req.body;

  if (!room_name || !room_description) {
    return res.status(400).json({ message: "Room name and description are required" });
  }

  try {
    const connection = await pool.promise().getConnection();
    try {
      const [existing] = await connection.query(`SELECT * FROM room WHERE room_name = ?`, [room_name]);
      if (existing.length > 0)
        return res.status(409).json({ message: "Room already exists" });

      const sql = `
        INSERT INTO room (room_name, room_description, timestatus8, timestatus10, timestatus13, timestatus15)
        VALUES (?, ?, 'Free', 'Free', 'Free', 'Free')
      `;
      const [result] = await connection.query(sql, [room_name, room_description]);

      return res.status(200).json({
        message: "Room added successfully",
        room_id: result.insertId
      });
    } finally {
      connection.release();
    }
  } catch (err) {
    console.error("Database error:", err);
    return res.status(500).json({ message: "Database Server Error" });
  }
});


// PUT /rooms/manage/edit body: { room_id, room_name, room_description }
// ========================== EDIT ROOM (ROLE: 1)======================
app.put('/rooms/manage/edit', verifyUser(["1"]), function (req, res) {
  const { room_id, room_name, room_description } = req.body;

  if (!room_id || !room_name || !room_description)
    return res.status(400).json({ message: "Missing required fields" });

  pool.query(
    `SELECT COUNT(*) AS count FROM room WHERE room_name = ? AND room_id != ?`,
    [room_name, room_id],
    (err, rows) => {
      if (err) return res.status(500).json({ message: "Database Server Error" });

      if (rows[0].count > 0)
        return res.status(409).json({ message: "Room name already exists" });

      pool.query(
        `UPDATE room SET room_name = ?, room_description = ? WHERE room_id = ?`,
        [room_name, room_description, room_id],
        (err2, result) => {
          if (err2) return res.status(500).json({ message: "Database Server Error" });
          if (result.affectedRows === 0)
            return res.status(404).json({ message: "Room not found" });

          return res.status(200).json({ message: "Room updated successfully" });
        }
      );
    }
  );
});


// PUT /rooms/manage/enaanddis body: { room_id, action } // action -> enable = free, disable = disable
// ========================== ENABLE & DISABLE ROOM (ROLE: 1)======================
app.put('/rooms/manage/enaanddis', verifyUser(["1"]), async function (req, res) {
  const { room_id, action } = req.body;

  if (!room_id || !["enable", "disable"].includes(action))
    return res.status(400).json({ message: "Room ID and valid action are required" });

  try {
    const connection = await pool.promise().getConnection();
    try {
      const [rows] = await connection.query(
        `SELECT timestatus8, timestatus10, timestatus13, timestatus15 FROM room WHERE room_id = ?`,
        [room_id]
      );

      if (rows.length === 0) return res.status(404).json({ message: "Room not found" });

      const statuses = Object.values(rows[0]);
      const allAllowed = statuses.every(s => s === "Free" || s === "Disable");
      if (!allAllowed)
        return res.status(400).json({ message: "Cannot enable/disable due to active slots" });

      let sql;
      if (action === "disable") {
        sql = `
          UPDATE room SET
            timestatus8 = CASE WHEN timestatus8='Free' THEN 'Disable' ELSE timestatus8 END,
            timestatus10 = CASE WHEN timestatus10='Free' THEN 'Disable' ELSE timestatus10 END,
            timestatus13 = CASE WHEN timestatus13='Free' THEN 'Disable' ELSE timestatus13 END,
            timestatus15 = CASE WHEN timestatus15='Free' THEN 'Disable' ELSE timestatus15 END
          WHERE room_id = ?
        `;
      } else {
        sql = `
          UPDATE room SET
            timestatus8 = CASE WHEN timestatus8='Disable' THEN 'Free' ELSE timestatus8 END,
            timestatus10 = CASE WHEN timestatus10='Disable' THEN 'Free' ELSE timestatus10 END,
            timestatus13 = CASE WHEN timestatus13='Disable' THEN 'Free' ELSE timestatus13 END,
            timestatus15 = CASE WHEN timestatus15='Disable' THEN 'Free' ELSE timestatus15 END
          WHERE room_id = ?
        `;
      }

      await connection.query(sql, [room_id]);
      return res.status(200).json({ message: `Room ${action}d successfully` });

    } finally {
      connection.release();
    }
  } catch (err) {
    console.error("Database error:", err);
    return res.status(500).json({ message: "Database Server Error" });
  }
});


// ========================= DASHBOARD (ROLE: 1,2) ===============================
app.get("/slotdashboard", verifyUser(["1", "2"]), async function (req, res) {
  const currentHour = getCurrentHourFrac();
  const now = getNowDate();

  const slotEnds = {
    8: 10,
    10: 12,
    13: 15,
    15: 17
  };

  try {
    const [rows] = await pool.promise().query(`
      SELECT 
          timestatus8, timestatus10, timestatus13, timestatus15
      FROM room
    `);

    let free = 0,
      pending = 0,
      reserved = 0,
      disabled = 0;

    for (const row of rows) {
      const statuses = {
        8: row.timestatus8,
        10: row.timestatus10,
        13: row.timestatus13,
        15: row.timestatus15
      };

      for (const [slot, stat] of Object.entries(statuses)) {
        if (slotEnds[slot] > currentHour) {
          if (stat === "Free") free++;
          else if (stat === "Pending") pending++;
          else if (stat === "Reserved") reserved++;
        }
      }

      if (
        row.timestatus8 === "Disable" &&
        row.timestatus10 === "Disable" &&
        row.timestatus13 === "Disable" &&
        row.timestatus15 === "Disable"
      ) {
        disabled++;
      }
    }

    const formattedDate =
      `${String(now.getDate()).padStart(2, "0")}/${String(now.getMonth() + 1).padStart(2, "0")}/${now.getFullYear()}`;

    res.status(200).json({
      date: formattedDate,
      currentHour,
      freeSlots: free.toString(),
      pendingSlots: pending.toString(),
      reservedSlots: reserved.toString(),
      disabledSlots: disabled.toString()
    });
  } catch (err) {
    console.error("Database error:", err);
    return res.status(500).json({ message: "Database error" });
  }
});



// ========================= FETCH PENDING REQUEST (ROLE 2) ===============================
app.get("/pending-requests", verifyUser(["2"]), function (req, res) {
  const sql = `
    SELECT 
        b.request_id,
        u.username,
        b.room_name,
        b.booking_date,
        b.booking_time,
        b.reason,
        u.UserID
    FROM booking b
    JOIN users u ON b.User_id = u.UserID
    WHERE b.booking_status = 'pending'
    ORDER BY b.booking_date ASC, b.booking_time ASC
  `;

  pool.query(sql, function (err, rows) {
    if (err) {
      console.error("Database error:", err);
      return res.status(500).json({ message: "Database error" });
    }

    const timeMap = {
      "8": "08:00 - 10:00",
      "10": "10:00 - 12:00",
      "13": "13:00 - 15:00",
      "15": "15:00 - 17:00"
    };

    const monthNames = [
      "January", "February", "March", "April", "May", "June",
      "July", "August", "September", "October", "November", "December"
    ];

    const formatted = rows.map(row => {
      const dt = new Date(row.booking_date);
      const formattedDate = `${dt.getDate()} ${monthNames[dt.getMonth()]} ${dt.getFullYear()}`;

      return {
        request_id: row.request_id,
        username: row.username,
        room_name: row.room_name,
        booking_date: formattedDate,
        booking_time: timeMap[row.booking_time?.toString()] || "-",
        reason: row.reason
      };
    });

    res.status(200).json(formatted);
  });
});

// POST /update-requests body: { request_id, status } // status = 'approve' || 'reject'
// ========================= APPROVER UPDATE REQUESTS (ROLE 2) ===============================
app.post("/update-requests", verifyUser(["2"]), async function (req, res) {
  const decisions = req.body;
  const approverId = req.decoded.uid;
  const approverName = req.decoded.name;

  if (!Array.isArray(decisions) || decisions.length === 0) {
    return res.status(400).json({ message: "No decisions provided" });
  }

  let connection;

  try {
    connection = await pool.promise().getConnection();
    await connection.beginTransaction();

    for (const decision of decisions) {
      const status = decision.status || decision.decisions;
      const reason = decision.reject_reason || null;

      if (!decision.request_id || !["approve", "reject", "pending"].includes(status)) {
        console.warn("Invalid decision:", decision);
        continue;
      }

      // update booking
      await connection.query(
        `
        UPDATE booking
        SET booking_status = ?,
            approver_name = ?,
            approve_id = ?,
            reject_reason = ?
        WHERE request_id = ?
      `,
        [
          status,
          approverName,
          approverId,
          status === "reject" ? reason : null,
          decision.request_id
        ]
      );

      const [booking] = await connection.query(
        `SELECT room_id, booking_time FROM booking WHERE request_id = ?`,
        [decision.request_id]
      );

      if (booking.length > 0) {
        const roomId = booking[0].room_id;
        const time = booking[0].booking_time;

        if (status === "approve") {
          await connection.query(
            `UPDATE room SET timestatus${time} = 'Reserved' WHERE room_id = ?`,
            [roomId]
          );
        }

        if (status === "reject") {
          await connection.query(
            `UPDATE room SET timestatus${time} = 'Free' WHERE room_id = ?`,
            [roomId]
          );
        }
      }
    }

    await connection.commit();
    return res.status(200).json({
      success: true,
      message: "Requests updated successfully"
    });

  } catch (err) {
    if (connection) await connection.rollback();
    console.error("Database error:", err);
    return res.status(500).json({
      success: false,
      message: "Database error"
    });
  } finally {
    if (connection) connection.release();
  }
});



// ===================== HISTORY FOR ALL ROLES ==========================
app.get("/history/info", verifyUser(["0", "1", "2"]), function (req, res) {
  const uid = req.decoded.uid;
  const role = req.decoded.role;

  let sql, params;

  switch (role) {
    case "0": // normal user
      sql = `
        SELECT b.*, r.room_name, r.room_description,
               u.name AS booker_name,
               a.name AS approver_name
        FROM booking b
        JOIN room r ON b.room_id = r.room_id
        JOIN users u ON b.User_id = u.UserID
        LEFT JOIN users a ON b.approve_id = a.UserID
        WHERE b.User_id = ?
        ORDER BY b.booking_date DESC, b.booking_time DESC, b.created_at DESC
      `;
      params = [uid];
      break;

    case "1": // staff: see all
      sql = `
        SELECT b.*, r.room_name, r.room_description,
               u.name AS booker_name,
               a.name AS approver_name
        FROM booking b
        JOIN room r ON b.room_id = r.room_id
        JOIN users u ON b.User_id = u.UserID
        LEFT JOIN users a ON b.approve_id = a.UserID
        ORDER BY b.booking_date DESC, b.booking_time DESC, b.created_at DESC
      `;
      params = [];
      break;

    case "2": // approver
      sql = `
        SELECT b.*, r.room_name, r.room_description,
               u.name AS booker_name,
               a.name AS approver_name
        FROM booking b
        JOIN room r ON b.room_id = r.room_id
        JOIN users u ON b.User_id = u.UserID
        LEFT JOIN users a ON b.approve_id = a.UserID
        WHERE b.approve_id = ? OR b.booking_status = 'pending'
        ORDER BY b.booking_date DESC, b.booking_time DESC, b.created_at DESC
      `;
      params = [uid];
      break;

    default:
      return res.status(401).json({ message: "Invalid role" });
  }

  pool.query(sql, params, function (err, rows) {
    if (err) {
      console.error("Database error:", err);
      return res.status(500).json({ message: "Database Server Error" });
    }

    const timeSlotMap = {
      "8": "08.00 - 10.00",
      "10": "10.00 - 12.00",
      "13": "13.00 - 15.00",
      "15": "15.00 - 17.00"
    };

    const formatted = rows.map(b => {
      const d = new Date(b.booking_date);
      const formattedDate = `${d.getDate()}/${d.getMonth() + 1}/${String(d.getFullYear()).slice(-2)}`;

      const createdAt = b.created_at ? new Date(b.created_at) : new Date();
      const formattedTime = `${String(createdAt.getHours()).padStart(2, "0")}:${String(createdAt.getMinutes()).padStart(2, "0")}`;

      let approverName = b.approver_name;
      if (!approverName && b.booking_status === "reject") approverName = "System";
      if (!approverName) approverName = "-";

      return {
        room: b.room_name,
        booking_date: formattedDate,
        booking_time: formattedTime,
        booking_timeslot: timeSlotMap[b.booking_time?.toString()] || "Unknown",
        booker_name: b.booker_name,
        status: b.booking_status,
        approver_name: approverName
      };
    });

    res.status(200).json(formatted);
  });
});

//  Timeslot 

const cron = require('node-cron');

// ============================= RESET FUNCTION =============================  // RESET status เป็น free ยกเว้น disable
function resetAllToFree() {
    const currentTime = getCurrentTime();
    console.log(`⏰ Checking status for time: ${currentTime.hour}:${currentTime.minute.toString().padStart(2, '0')}`);
    console.log(`♻️ Checking morning reset at ${currentTime.hour}:${currentTime.minute.toString().padStart(2, '0')}`);

    if (!isEarlyMorningReset(currentTime)) return;

    const sql = `
        UPDATE room
        SET
            timestatus8 = CASE WHEN timestatus8 = 'Disable' THEN 'Disable' ELSE 'Free' END,
            timestatus10 = CASE WHEN timestatus10 = 'Disable' THEN 'Disable' ELSE 'Free' END,
            timestatus13 = CASE WHEN timestatus13 = 'Disable' THEN 'Disable' ELSE 'Free' END,
            timestatus15 = CASE WHEN timestatus15 = 'Disable' THEN 'Disable' ELSE 'Free' END
    `;

    pool.query(sql, (err) => {
        if (err) {
            console.error('❌ Database error (morning reset):', err);
            return;
        }
        console.log('✅ Morning reset completed — all available slots set to Free.');
    });
}

// ============================= AUTO-REJECT FUNCTION =============================  // Reject auto ถ้ามี pending ค้างแล้วหมดเวลา -> reject โดย system
function autoRejectExpiredBookings() {
    const currentTime = getCurrentTime();
    console.log(`⏰ Checking status for time: ${currentTime.hour}:${currentTime.minute.toString().padStart(2, '0')}`);
    console.log(`🕔 Checking for expired pending bookings at ${currentTime.hour}:${currentTime.minute.toString().padStart(2, '0')}`);

    if (!isEndOfDay(currentTime)) return;

    const sql = `
        UPDATE booking
        SET booking_status = 'reject',
            approver_name = 'System',
            approve_id = NULL
        WHERE booking_status = 'pending'
    `;

    pool.query(sql, (err, result) => {
        if (err) {
            console.error('❌ Database error (auto-reject):', err);
            return;
        }

        if (result.affectedRows > 0) {
            console.log(`🚫 Auto-rejected ${result.affectedRows} pending bookings after end of day.`);
        } else {
            console.log('✅ No pending bookings to reject.');
        }
    });
}

// ============================= SCHEDULER =============================

// Run every minute — uses either simulated or real time  // timesim = null
cron.schedule('* * * * *', () => {
    const now = getCurrentTime();
    const hourStr = now.hour.toString().padStart(2, '0');
    const minuteStr = now.minute.toString().padStart(2, '0');
    console.log(`⏰ Checking status for time: ${hourStr}:${minuteStr}`);

    if (isEarlyMorningReset(now)) resetAllToFree();
    if (isEndOfDay(now)) autoRejectExpiredBookings();
});

console.log('🕒 Room timeslot cron scheduler active — checks every minute.');



const port = 3005;
app.listen(port,'0.0.0.0', function(){
    console.log(`Server is running on ${port}`)
})


