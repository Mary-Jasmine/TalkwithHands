import mongoose from 'mongoose';

const feedbackSchema = new mongoose.Schema(
  {
    rating: { type: Number, default: 0 },
    review: { type: String, default: '' },
    updated_at: { type: Date },
  },
  { _id: false }
);

const avatarPreferencesSchema = new mongoose.Schema(
  {
    character: { type: String, default: 'hera' },
    skin_tone: { type: String, default: 'default' },
    outfit: { type: String, default: 'school' },
  },
  { _id: false }
);

const userSchema = new mongoose.Schema(
  {
    username: { type: String, required: true, trim: true },
    email: { type: String, required: true, unique: true, lowercase: true, trim: true },
    password: { type: String, required: true },
    photo_url: { type: String, default: '' },
    cover_photo_url: { type: String, default: '' },
    stars: { type: Number, default: 0 },
    coins: { type: Number, default: 0 },
    unlocked_levels: { type: [Number], default: [1] },
    address: { type: String, default: '' },
    contact_number: { type: String, default: '' },
    sex: { type: String, default: '' },
    age: { type: Number },
    app_feedback: { type: feedbackSchema, default: () => ({}) },
    avatar_preferences: { type: avatarPreferencesSchema, default: () => ({}) },
  },
  { timestamps: true }
);

export default mongoose.models.User || mongoose.model('User', userSchema);
