const express = require('express');
const path = require('path');
const pool = require('./config/db.js');
const bcrypt = require('bcrypt');
const session = require('express-session');
const app = express();
const mysql = require('mysql2');

// Add session middleware
app.use(session({
    secret: 'your-secret-key',
    resave: true,
    saveUninitialized: true,
    rolling: true, // Refresh cookie expiration on every response
    cookie: { 
        secure: false, // Set to true if using HTTPS
        maxAge: 24 * 60 * 60 * 1000 // 24 hours in milliseconds
    }
}));

app.use('/public', express.static(path.join(__dirname, "public")));
app.use(express.json());


const timesim = 9; // ทดสอบเวลา: Ex. timesim = 9, null = ใช้เวลาจริง.  timesim=6 reset สถานะ

// Return a Date object adjusted for simulated time
function getNowDate() {
  if (timesim === null) return new Date();
  const now = new Date();
  return new Date(now.getFullYear(), now.getMonth(), now.getDate(), timesim, 0, 0, 0);
}

// Return fractional hour (e.g. 11.5)
function getCurrentHourFrac() {
  const d = getNowDate();
  return d.getHours() + d.getMinutes() / 60;
}

// For cron/logging use
function getCurrentTime() {
  const d = getNowDate();
  return { hour: d.getHours(), minute: d.getMinutes() };
}

function isEarlyMorningReset(time) {
  return time.hour === 6;
}

function isEndOfDay(time) {
  return time.hour >= 17; // after 5 PM
}

// ใน body มี username, password
// {
//     "username": "Mike_Student",
//     "password": "1234"
// }
app.post("/login", async function(req,res){    // POST response output ออกมาเป็น json: {message: "Login Successful"}
    const username = req.body.username;
    const password = req.body.password;

    try {
        const connection = await pool.promise().getConnection();
        try {
            const sql = `SELECT UserID, name, username, role, password FROM users WHERE username = ?`;
            const [result] = await connection.query(sql, [username]);
            
            if (result.length !== 1) {
                res.status(401).send("Wrong username or password");
                return;
            }

                try {
                    const isHashed = result[0].password.startsWith('$2b$');
                    let match;
                
                    if (isHashed) {
                        match = await bcrypt.compare(password, result[0].password);
                    } else {
                        match = password === result[0].password;
                        
                        if (match) {
                            const saltRounds = 10;
                            const hashedPassword = await bcrypt.hash(password, saltRounds);
                        await connection.query(
                            `UPDATE users SET password = ? WHERE UserID = ?`,
                            [hashedPassword, result[0].UserID]
                        );
                        }
                    }
                    
                    if (!match) {
                        res.status(401).send("Wrong username or password");
                        return;
                    }

                    let formattedId;
                    const userId = result[0].UserID.toString().padStart(3, '0');
                    switch(result[0].role) {
                    case "0": formattedId = `U${userId}`; break;
                    case "1": formattedId = `S${userId}`; break;
                    case "2": formattedId = `A${userId}`; break;
                    default: formattedId = userId;
                }

                    req.session.userId = result[0].UserID;
                    req.session.userRole = result[0].role;
                    req.session.userName = result[0].name;
                    req.session.username = result[0].username;
                    
                    // return
                    res.status(200).json({
                        message: "Login Successful",
                        role: result[0].role,
                        userId: result[0].UserID,
                        formattedId: formattedId,
                        name: result[0].name,
                        username: result[0].username
                    });
                } catch (error) {
                    console.error('Password comparison error:', error);
                    res.status(500).send("Something went wrong");
                }
        } finally {
            connection.release();
            }
    } catch (error) {
        console.error('Database error:', error);
        res.status(500).send("Database Server Error");
        }
})

// ใน body มี name, username, password, role
// {
//     "name": "John Doe",
//     "username": "johnfarmer",
//     "password": "1234",
//     "role": "0"
//  }
app.post("/register", async function(req, res) {
    const name = req.body.name;
    const username = req.body.username;
    const password = req.body.password;
    const role = req.body.role;

    // Validate input
    if (!name || !username || !password) {
        return res.status(400).json({ message: "All fields are required" });
    }

    try {
        const connection = await pool.promise().getConnection();
        try {
    // First check if username already exists
    const checkUsername = "SELECT * FROM users WHERE username = ?";
            const [existingUsers] = await connection.query(checkUsername, [username]);

            if (existingUsers.length > 0) {
            return res.status(409).json({ message: "Username already exists" });
        }

            // Hash the password
            const saltRounds = 10;
            const hashedPassword = await bcrypt.hash(password, saltRounds);

            // Insert new user
            const sql = `INSERT INTO users (name, username, password, role) VALUES (?, ?, ?, ?)`;
            await connection.query(sql, [name, username, hashedPassword, role]);
            
                    res.status(200).json({
                        message: "Registration Successful"
                    });
        } finally {
            connection.release();
                }
        } catch (error) {
        console.error('Database error:', error);
        res.status(500).json({ message: "Database Server Error" });
        }
});


app.post("/logout", function (req, res) {
  if (req.session) {
    req.session.destroy(err => {
      if (err) {
        console.error("Logout error:", err);
        return res.status(500).json({ message: "Failed to log out" });
      }
      res.clearCookie("connect.sid"); // optional: clear session cookie
      res.status(200).json({ message: "Logged out successful" });
    });
  } else {
    res.status(200).json({ message: "No active session" });
  }
});


// profile
// ได้ออกมา
// {
//     "name": "Mike BB",
//     "username": "Mike_Student",
//     "role": "0"
// }
app.get('/profile', async function (req, res) {
  const username = req.session?.username; // safer access

  if (!username) {
    return res.status(401).json({ message: 'Not logged in' });
  }

  try {
    const connection = await pool.promise().getConnection();
    try {
      const sql = `SELECT name, username FROM users WHERE username = ?`;
      const [result] = await connection.query(sql, [username]);

      if (result.length === 0) {
        return res.status(404).json({ message: 'User not found' });
      }

      res.status(200).json({
        name: result[0].name,
        username: result[0].username,
        role: req.session.userRole, // เก็บใน session
      });
    } finally {
      connection.release();
    }
  } catch (error) {
    console.error('Database error:', error);
    res.status(500).json({ message: 'Database Server Error' });
  }
});


// http://localhost:3005/rooms/info?date=2025-10-24
// Browseroom
// ได้ออกมา
// [
//     {
//         "room_id": 32,
//         "room_name": "A7-128",
//         "room_description": "blablablablabla",
//         "timeSlots": {
//             "08.00 - 10.00": "Free"
//             "10.00 - 12.00": "Pending"
//             "13.00 - 15.00": "Reserved"
//             "15.00 - 17.00": "Reserved"
//         }
//     },...
// ]
app.get("/rooms/info", async function (req, res) {
  if (!req.session?.userId) {
    return res.status(401).json({ message: "Unauthorized - Please login first" });
  }

  const selectedDate = req.query.date;
  if (!selectedDate) {
    return res.status(400).json({ message: "Date query is required" });
  }

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

      const now = getNowDate();
      const currentHour = getCurrentHourFrac();

      // Define slot start and end times
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

          // ✅ Remove slots that have already ended
          for (const [key, value] of Object.entries(timeSlots)) {
            const [start, end] = slotRanges[key];
            if (end <= currentHour || value === 'Unavailable') {
              delete timeSlots[key];
            }
          }

          rooms[row.room_name] = {
            room_id: row.room_id,
            room_name: row.room_name,
            room_description: row.room_description,
            timeSlots: timeSlots
          };
        }

        // ✅ Update slot with booking status
        if (row.booking_time) {
          const time = row.booking_time.toString();
          if (rooms[row.room_name].timeSlots[time] !== undefined) {
            if (row.booking_status === 'approve') {
              rooms[row.room_name].timeSlots[time] = 'Reserved';
            } else if (row.booking_status === 'pending') {
              rooms[row.room_name].timeSlots[time] = 'Pending';
            }
          }
        }
      });

      const roomsArray = Object.values(rooms);
      res.status(200).json(roomsArray);
    } finally {
      connection.release();
    }
  } catch (error) {
    console.error("Database error:", error);
    res.status(500).json({ message: "Database Server Error" });
  }
});


// http://localhost:3005/rooms/request/info?date=2025-10-24
// request room  // get only free status
// ได้ออกมา เหมือน browseroom แต่เฉพาะ free
app.get("/rooms/request/info", async function (req, res) {
  if (!req.session?.userId || req.session?.userRole !== "0") {
    return res.status(401).json({ message: "Unauthorized - Please login first" });
  }

  if (!req.query.date) {
    return res.status(400).json({ message: "Date query is required" });
  }

  try {
    const connection = await pool.promise().getConnection();
    try {
      const selectedDate = req.query.date;
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

      // current fractional hour (e.g. 11.33)
      const now = getNowDate();
      const currentHourFrac = getCurrentHourFrac();

      // slot start/end ranges
      const slotRanges = {
        "08.00 - 10.00": [8, 10],
        "10.00 - 12.00": [10, 12],
        "13.00 - 15.00": [13, 15],
        "15.00 - 17.00": [15, 17]
      };

      // only treat "past" relative to server now when selectedDate is today
      const todayIso = getNowDate().toISOString().split('T')[0];
      const isSelectedDateToday = selectedDate === todayIso;

      const rooms = {};

      result.forEach(row => {
        if (!rooms[row.room_name]) {
          const allTimeSlots = {
            "08.00 - 10.00": row.timestatus8,
            "10.00 - 12.00": row.timestatus10,
            "13.00 - 15.00": row.timestatus13,
            "15.00 - 17.00": row.timestatus15
          };

          const filteredSlots = Object.fromEntries(
            Object.entries(allTimeSlots).filter(([key, status]) => {
              // must be Free
              if (status !== 'Free') return false;

              // if viewing today, exclude slots that have ended
              if (isSelectedDateToday) {
                const [, end] = slotRanges[key];
                return end > currentHourFrac;
              }

              // future date (or other date) => keep Free slots
              return true;
            })
          );

          if (Object.keys(filteredSlots).length > 0) {
            rooms[row.room_name] = {
              room_id: row.room_id,
              room_name: row.room_name,
              room_description: row.room_description,
              timeSlots: filteredSlots
            };
          }
        }
      });

      res.status(200).json(Object.values(rooms));
    } finally {
      connection.release();
    }
  } catch (error) {
    console.error("Database error:", error);
    res.status(500).json({ message: "Database Server Error" });
  }
});

// ใน body มี room_id, date, timeSlot, reason
// {
//     "room_id": "35",
//     "date": "2025-10-24",
//     "timeSlot": "15",
//     "reason": "Study group meeting"
// }
app.post("/rooms/request", async function(req, res) {
    // Check if user is logged in and has user role
    if (!req.session?.userId || req.session?.userRole !== "0") {
        res.status(401).json({ message: "Unauthorized - Please login first" });
        return;
    }

    // Validate input
    const { room_id, date, timeSlot, reason } = req.body;
    if (!room_id || !date || !timeSlot || !reason) {
        res.status(400).json({ message: "Missing required fields" });
        return;
    }

    let connection;
    try {
        // Get a connection from the pool
        connection = await pool.promise().getConnection();
        
        // Start transaction
        await connection.beginTransaction();

        try {
            // Check if user already has a booking for this date
            const checkBookingSql = `
                SELECT * FROM booking 
                WHERE User_id = ? AND booking_date = ? AND booking_status != 'reject'
            `;
            const [existingBookings] = await connection.query(checkBookingSql, [req.session.userId, date]);

            if (existingBookings.length > 0) {
                await connection.rollback();
                res.status(400).json({ message: "You already have a booking for this date" });
            return;
        }

            // Check room availability
            const checkRoomSql = `
                SELECT * FROM room 
                WHERE room_id = ? AND timestatus${timeSlot} = 'Free'
            `;
            const [rooms] = await connection.query(checkRoomSql, [room_id]);

            if (rooms.length === 0) {
                await connection.rollback();
                res.status(400).json({ message: "Room is not available for the selected time slot" });
                return;
            }

            // Insert new booking
            const insertBookingSql = `
                INSERT INTO booking (User_id, room_id, booking_date, booking_time, reason, booking_status)
                VALUES (?, ?, ?, ?, ?, 'pending')
            `;
            await connection.query(insertBookingSql, [
                req.session.userId,
                room_id,
                date,
                timeSlot,
                reason
            ]);

            // Update room status
            const updateRoomSql = `
                UPDATE room 
                SET timestatus${timeSlot} = 'Pending'
                WHERE room_id = ?
            `;
            await connection.query(updateRoomSql, [room_id]);

            // Commit transaction
            await connection.commit();

            res.status(200).json({ message: "Reservation submitted successfully" });
        } catch (error) {
            // Rollback transaction on error
            await connection.rollback();
            throw error;
        }
    } catch (error) {
        console.error('Database error:', error);
        res.status(500).json({ message: "Database Server Error" });
    } finally {
        // Always release the connection back to the pool
        if (connection) {
            connection.release();
        }
    }
});




// check room // check status after request
// ได้ออกมา
// {
//     "bookings": [
//         {
//             "request_id": 315,
//             "room_name": "abc-123",
//             "room_description": "new room",
//             "booking_date": "24/10/2025",
//             "booking_time": "15:00 - 17:00",
//             "booking_status": "pending",
//             "reason": "Study group meeting"
//         }
//     ]
// } 
app.get("/rooms/check/info", async function (req, res) {
  if (!req.session?.userId || req.session?.userRole !== "0") {
    res.status(401).json({ message: "Unauthorized - Please login first" });
    return;
  }

  try {
    const connection = await pool.promise().getConnection();
    try {
      const userId = req.session.userId;
      const sql = `
        SELECT 
          b.*,
          r.room_name,
          r.room_description
        FROM booking b
        JOIN room r ON b.room_id = r.room_id
        WHERE b.User_id = ?
        AND b.booking_date = CURDATE()
        ORDER BY b.booking_date ASC, b.booking_time ASC
      `;

      const [result] = await connection.query(sql, [userId]);

      if (result.length === 0) {
        res.status(200).json({ bookings: [] });
        return;
      }

      // Map time slot codes to readable format
      const timeSlotMap = {
        "8": "08:00 - 10:00",
        "10": "10:00 - 12:00",
        "13": "13:00 - 15:00",
        "15": "15:00 - 17:00"
      };

      // Format results
      const formattedBookings = result.map(b => {
      const dateObj = new Date(b.booking_date);
      const formattedDate = `${String(dateObj.getDate()).padStart(2, "0")}/${String(dateObj.getMonth() + 1).padStart(2, "0")}/${dateObj.getFullYear()}`;
      const formattedTime = timeSlotMap[b.booking_time?.toString()] || "-";

      return {
        request_id: b.request_id,
        room_name: b.room_name,
        room_description: b.room_description,
        booking_date: formattedDate,
        booking_time: formattedTime,
        booking_status: b.booking_status,
        reason: b.reason
      };
    });

      res.status(200).json({ bookings: formattedBookings });
    } finally {
      connection.release();
    }
  } catch (error) {
    console.error("Database error:", error);
    res.status(500).json({ message: "Database Server Error" });
  }
});


// Manage room  // get room details เอาเฉพาะ free, disable
// ได้ออกมา
// [
//     {
//         "room_id": 3,
//         "room_name": "C1-313",
//         "room_description": "A lecture hall, Lcd projector, Screen, Amp, Mic and speaker with 160 available seats",
//         "timeSlots": {
//            "08:00 - 10:00": "Free",
//            "10:00 - 12:00": "Free",
//            "13:00 - 15:00": "Free",
//            "15:00 - 17:00": "Free"
//          }
//     },...
// ]
app.get('/rooms/manage/info', async function (req, res) {
  if (!req.session?.userId || req.session?.userRole !== "1") {
    res.status(401).json({ message: "Unauthorized - Staff access required" });
    return;
  }

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

      const [result] = await connection.query(sql);

      // Map slot labels
      const timeMap = {
        timestatus8: "08:00 - 10:00",
        timestatus10: "10:00 - 12:00",
        timestatus13: "13:00 - 15:00",
        timestatus15: "15:00 - 17:00"
      };

      // Filter only Free and Disable slots
      const formatted = result.map(room => {
        const timeSlots = {};
        for (const [key, label] of Object.entries(timeMap)) {
          if (room[key] === "Free" || room[key] === "Disable") {
            timeSlots[label] = room[key];
          }
        }

        return {
          room_id: room.room_id,
          room_name: room.room_name,
          room_description: room.room_description,
          timeSlots
        };
      }).filter(room => Object.keys(room.timeSlots).length > 0); // keep only rooms with at least 1 valid slot

      res.status(200).json(formatted);
    } finally {
      connection.release();
    }
  } catch (error) {
    console.error("Database error:", error);
    res.status(500).json({ message: "Database Server Error" });
  }
});




// Add room  // add room name, description after add all status is free
// ใน body มี room_name, room_description
// {
//     "room_name": "abc-123",
//     "room_description": "a new rooms"
// }
// ได้ออกมา
// {
//     "message": "Room added successfully",
//     "room_id": 35
// }
app.post('/rooms/manage/add', async function (req, res) {
    // Check if staff is logged in and has staff role
    if (!req.session?.userId || req.session?.userRole !== "1") {
        res.status(401).json({ message: "Unauthorized - Staff access required" });
        return;
    }

    const { room_name, room_description } = req.body;

    if (!room_name || !room_description) {
        res.status(400).json({ message: "Room name and description are required" });
        return;
    }

    try {
        const connection = await pool.promise().getConnection();
        try {
            // Check if room already exists
            const checkSql = "SELECT * FROM room WHERE room_name = ?";
            const [existingRooms] = await connection.query(checkSql, [room_name]);

            if (existingRooms.length > 0) {
                res.status(409).json({ message: "Room already exists" });
                return;
            }

            // Insert new room
            const insertSql = `
                INSERT INTO room (room_name, room_description, timestatus8, timestatus10, timestatus13, timestatus15)
                VALUES (?, ?, 'Free', 'Free', 'Free', 'Free')
            `;
            const [result] = await connection.query(insertSql, [room_name, room_description]);
            
            // Return room_id along with success message
            res.status(200).json({ 
                message: "Room added successfully", 
                room_id: result.insertId 
            });
        } finally {
            connection.release();
        }
    } catch (error) {
        console.error('Database error:', error);
        res.status(500).json({ message: "Database Server Error" });
    }
});

// Edit room  // edit room name, description
// ใน body มี room_id, room_name, room_description
// {
//     "room_id": 35,
//     "room_name": "abcs-123",
//     "room_description": "a new room"
// }
// ได้ออกมา
// {
//     "message": "Room updated successfully"
// }
app.put('/rooms/manage/edit', function (req, res) {
    // Check if staff is logged in and has staff role
    if (!req.session?.userId || req.session?.userRole !== "1") {
        res.status(401).json({ message: "Unauthorized - Staff access required" });
                return;
    }

    const { room_id, room_name, room_description } = req.body;
    
    // Validate required fields
    if (!room_id || !room_name || !room_description) {
        return res.status(400).json({ message: "Missing required fields" });
    }

    // First check if the new room name already exists (excluding current room)
    const checkSql = "SELECT COUNT(*) AS count FROM room WHERE room_name = ? AND room_id != ?";
    
    pool.query(checkSql, [room_name, room_id], (err, results) => {
        if (err) {
            console.error('Database error:', err);
            return res.status(500).json({ message: "Database Server Error" });
        }

        if (results[0].count > 0) {
            return res.status(409).json({ message: "Room name already exists" });
        }

        // Update room details
        const updateSql = "UPDATE room SET room_name = ?, room_description = ? WHERE room_id = ?";
        
        pool.query(updateSql, [room_name, room_description, room_id], (err, results) => {
            if (err) {
                console.error('Database error:', err);
                return res.status(500).json({ message: "Database Server Error" });
            } 
            
            if (results.affectedRows === 0) {
                return res.status(404).json({ message: "Room not found" });
            }
            
            res.status(200).json({ message: "Room updated successfully" });
        });
    });
});



// action -> enable = free, disable = disable
// ใน body มี room_id, action
// {
//   "room_id": 32,
//   "action": "enable"
// }
// ได้ออกมา
// {
//     "message": "Room enabled successfully"
// }
app.put('/rooms/manage/enaanddis', async function (req, res) {
  // Only staff allowed
  if (!req.session?.userId || req.session?.userRole !== "1") {
    return res.status(401).json({ message: "Unauthorized - Staff access required" });
  }

  const { room_id, action } = req.body;
  // action should be either "enable" or "disable"

  if (!room_id || !["enable", "disable"].includes(action)) {
    return res.status(400).json({ message: "Room ID and valid action (enable/disable) are required" });
  }

  const newStatus = action === "enable" ? "Free" : "Disable";

  try {
    const connection = await pool.promise().getConnection();
    try {
      const sql = `
        UPDATE room SET 
          timestatus8 = ?, 
          timestatus10 = ?, 
          timestatus13 = ?, 
          timestatus15 = ?
        WHERE room_id = ?
      `;
      await connection.query(sql, [newStatus, newStatus, newStatus, newStatus, room_id]);

      res.status(200).json({ message: `Room ${action}d successfully` });
    } finally {
      connection.release();
    }
  } catch (error) {
    console.error('Database error:', error);
    res.status(500).json({ message: "Database Server Error" });
  }
});


// show dashboard sum all status
// ได้ออกมา 
// {
//     "date": "24/10/2025",
//     "freeSlots": "35",
//     "pendingSlots": "1",
//     "reservedSlots": "0",
//     "disabledSlots": "4"
// }
app.get("/slotdashboard", function (req, res) {
  // Check if user is logged in and has appropriate role
  if (
    !req.session?.userId ||
    (req.session?.userRole !== "1" && req.session?.userRole !== "2")
  ) {
    res.status(401).json({ message: "Unauthorized" });
    return;
  }

  const query = `
      SELECT 
          SUM(CASE WHEN timestatus8 = 'Free' THEN 1 ELSE 0 END 
              + CASE WHEN timestatus10 = 'Free' THEN 1 ELSE 0 END 
              + CASE WHEN timestatus13 = 'Free' THEN 1 ELSE 0 END 
              + CASE WHEN timestatus15 = 'Free' THEN 1 ELSE 0 END) AS freeSlots,
          SUM(CASE WHEN timestatus8 = 'Pending' THEN 1 ELSE 0 END 
              + CASE WHEN timestatus10 = 'Pending' THEN 1 ELSE 0 END 
              + CASE WHEN timestatus13 = 'Pending' THEN 1 ELSE 0 END 
              + CASE WHEN timestatus15 = 'Pending' THEN 1 ELSE 0 END) AS pendingSlots,
          SUM(CASE WHEN timestatus8 = 'Reserved' THEN 1 ELSE 0 END 
              + CASE WHEN timestatus10 = 'Reserved' THEN 1 ELSE 0 END 
              + CASE WHEN timestatus13 = 'Reserved' THEN 1 ELSE 0 END 
              + CASE WHEN timestatus15 = 'Reserved' THEN 1 ELSE 0 END) AS reservedSlots,
          SUM(CASE WHEN timestatus8 = 'Disable' THEN 1 ELSE 0 END 
              + CASE WHEN timestatus10 = 'Disable' THEN 1 ELSE 0 END 
              + CASE WHEN timestatus13 = 'Disable' THEN 1 ELSE 0 END 
              + CASE WHEN timestatus15 = 'Disable' THEN 1 ELSE 0 END) AS disabledSlots 
      FROM room;
  `;

  pool.query(query, (err, result) => {
    if (err) {
      console.error("Database error:", err);
      return res.status(500).json({ message: "Database error" });
    }

    // Format current date as DD/MM/YYYY
    const today = getNowDate();
    const formattedDate = `${today.getDate().toString().padStart(2, "0")}/${(today.getMonth() + 1)
      .toString()
      .padStart(2, "0")}/${today.getFullYear()}`;

    // Combine date with slot summary
    res.status(200).json({
      date: formattedDate,
      ...result[0],
    });
  });
});


// get pending request from user after use booking
// ได้ออกมา
// [
//     {
//         "request_id": 314,
//         "username": "Mike_Student",
//         "room_name": "abcs-123",
//         "booking_date": "24 October 2025",
//         "booking_time": "15:00 - 17:00",
//         "reason": "Study group meeting"
//     },...
// ]
app.get("/pending-requests", function(req, res) {
  if (!req.session?.userId || req.session?.userRole !== "2") {
    res.status(401).json({ message: "Unauthorized" });
    return;
  }

  const sql = `
      SELECT 
          b.request_id,
          u.username,
          b.room_name,
          b.booking_date,
          b.booking_time,
          b.reason
      FROM booking b
      JOIN users u ON b.User_id = u.UserID
      WHERE b.booking_status = 'pending'
      ORDER BY b.booking_date ASC, b.booking_time ASC
  `;

  pool.query(sql, function(err, result) {
    if (err) {
      console.error("Database error:", err);
      res.status(500).json({ message: "Database error" });
      return;
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

    const formattedRows = result.map(row => {
      const dateObj = new Date(row.booking_date);
      const formattedDate = `${dateObj.getDate()} ${monthNames[dateObj.getMonth()]} ${dateObj.getFullYear()}`;
      const formattedTime = timeMap[row.booking_time?.toString()] || "-";

      return {
        ...row,
        booking_date: formattedDate,
        booking_time: formattedTime
      };
    });

    res.status(200).json(formattedRows);
  });
});


// Approve/reject user's request
// ใน body มี request_id, status
// [
//     {
//         "request_id": 306,
//         "status": "approve"  หรือ reject
//     }
// ]
// ได้ออกมา
// {
//     "success": true,
//     "message": "Requests updated successfully"
// }
app.post("/update-requests", async function (req, res) {
  if (!req.session?.userId || req.session?.userRole !== "2") {
    return res.status(401).json({ message: "Unauthorized" });
  }

  const decisions = req.body;
  if (!Array.isArray(decisions) || decisions.length === 0) {
    return res.status(400).json({ message: "No decisions provided" });
  }

  let connection;
  try {
    connection = await pool.promise().getConnection();
    await connection.beginTransaction();

    for (const decision of decisions) {
      // ✅ FIX — use both 'status' and 'decisions' as valid keys (fallback)
      const status = decision.status || decision.decisions;

      // ✅ validate status
      if (!decision.request_id || !["approve", "reject", "pending"].includes(status)) {
        console.warn("Invalid decision:", decision);
        continue;
      }

      // ✅ update booking table
      const updateBookingSql = `
        UPDATE booking
        SET booking_status = ?,
            approver_name = ?,
            approve_id = ?
        WHERE request_id = ?
      `;
      await connection.query(updateBookingSql, [
        status,
        req.session.userName,
        req.session.userId,
        decision.request_id,
      ]);

      // ✅ If approved — mark time slot as Reserved
      if (status === "approve") {
        const [booking] = await connection.query(
          `SELECT room_id, booking_time FROM booking WHERE request_id = ?`,
          [decision.request_id]
        );
        if (booking.length > 0) {
          await connection.query(
            `UPDATE room 
             SET timestatus${booking[0].booking_time} = 'Reserved'
             WHERE room_id = ?`,
            [booking[0].room_id]
          );
        }
      }

      // ✅ If rejected — mark time slot as Free
      if (status === "reject") {
        const [booking] = await connection.query(
          `SELECT room_id, booking_time FROM booking WHERE request_id = ?`,
          [decision.request_id]
        );
        if (booking.length > 0) {
          await connection.query(
            `UPDATE room 
             SET timestatus${booking[0].booking_time} = 'Free'
             WHERE room_id = ?`,
            [booking[0].room_id]
          );
        }
      }
    }

    // ✅ commit transaction
    await connection.commit();

    res.status(200).json({
      success: true,
      message: "Requests updated successfully",
    });
  } catch (error) {
    if (connection) await connection.rollback();
    console.error("Database error:", error);
    res.status(500).json({
      success: false,
      message: "Database error",
    });
  } finally {
    if (connection) connection.release();
  }
});

// get history based on each role
// ได้ออกมา
// [
//     {
//         "room": "abcs-123",
//         "booking_date": "24/10/25",
//         "booking_time": "12:48",
//         "booking_timeslot": "15.00 - 17.00",
//         "booker_name": "Mike_Student",
//         "status": "pending",
//         "approver_name": "-"
//     }
// ]
app.get("/history/info", function (req, res) {
  if (!req.session?.userId) {
    res.status(401).json({ message: "Unauthorized - Please login first" });
    return;
  }

  const userId = req.session.userId;
  const userRole = req.session.userRole;

  let sql, params;

  switch (userRole) {
    case "0": // User — show their own booking history
      sql = `
        SELECT 
            b.*,
            r.room_name,
            r.room_description,
            u.name AS booker_name,
            a.name AS approver_name
        FROM booking b
        JOIN room r ON b.room_id = r.room_id
        JOIN users u ON b.User_id = u.UserID
        LEFT JOIN users a ON b.approve_id = a.UserID
        WHERE b.User_id = ?
        ORDER BY b.booking_date DESC, b.booking_time DESC
      `;
      params = [userId];
      break;

    case "1": // Staff — all bookings
      sql = `
        SELECT 
            b.*,
            r.room_name,
            r.room_description,
            u.name AS booker_name,
            a.name AS approver_name
        FROM booking b
        JOIN room r ON b.room_id = r.room_id
        JOIN users u ON b.User_id = u.UserID
        LEFT JOIN users a ON b.approve_id = a.UserID
        ORDER BY b.booking_date DESC, b.booking_time DESC
      `;
      params = [];
      break;

    case "2": // Approver — their approved/rejected bookings
      sql = `
        SELECT 
            b.*,
            r.room_name,
            r.room_description,
            u.name AS booker_name,
            a.name AS approver_name
        FROM booking b
        JOIN room r ON b.room_id = r.room_id
        JOIN users u ON b.User_id = u.UserID
        LEFT JOIN users a ON b.approve_id = a.UserID
        WHERE b.approve_id = ? OR b.booking_status = 'pending'
        ORDER BY b.booking_date DESC, b.booking_time DESC
      `;
      params = [userId];
      break;

    default:
      res.status(401).json({ message: "Unauthorized - Invalid role" });
      return;
  }

  pool.query(sql, params, function (err, results) {
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

    const formattedResults = results.map(booking => {
      // 🔹 Date in DD/MM/YY (+543 for Buddhist year)
        const date = new Date(booking.booking_date);
        const formattedDate = `${date.getDate()}/${date.getMonth() + 1}/${date.getFullYear().toString().slice(-2)}`;

      // 🔹 Timestamp for when booking was created (not current)
      const timeSource = booking.created_at || booking.timestamp || booking.booking_date;
      const timeObj = new Date(timeSource);
      const formattedTime = `${timeObj.getHours().toString().padStart(2, "0")}:${timeObj.getMinutes().toString().padStart(2, "0")}`;

      // 🔹 Approver name handling
      let displayApproverName = booking.approver_name;
      if (!displayApproverName && booking.booking_status === "reject") {
        displayApproverName = "System";
      } else if (!displayApproverName) {
        displayApproverName = "-";
      }

      // 🔹 Add time slot label
      const bookingSlot = timeSlotMap[booking.booking_time?.toString()] || "Unknown";

      return {
        room: booking.room_name,
        booking_date: formattedDate,
        booking_time: formattedTime,
        booking_timeslot: bookingSlot,
        booker_name: booking.booker_name,
        status: booking.booking_status,
        approver_name: displayApproverName
      };
    });

    res.status(200).json(formattedResults);
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


